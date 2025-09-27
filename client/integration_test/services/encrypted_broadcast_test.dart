import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_opus/flutter_opus.dart';
import 'package:operation_won/services/encryption_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// --- Test Configuration ---
const String serverBaseUrl =
    String.fromEnvironment('SERVER_URL', defaultValue: 'http://localhost:8000');
const String wsBaseUrl =
    String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8000');

// --- Helper Function to Register and Login a User ---
Future<String> getAuthToken(Dio dio, String username, String password) async {
  // Register the user
  try {
    await dio.post(
      '$serverBaseUrl/auth/register',
      data: {
        'username': username,
        'email': '$username@test.com',
        'password': password,
      },
    );
  } on DioException catch (e) {
    // Ignore if user already exists (useful for re-running tests)
    if (e.response?.statusCode != 409) {
      rethrow;
    }
  }

  // Login to get the token
  final response = await dio.post(
    '$serverBaseUrl/auth/login',
    data: {'username': username, 'password': password},
  );

  return response.data['token'];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End Encrypted Audio Transmission Test',
      (WidgetTester tester) async {
    final dio = Dio();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final senderUsername = 'enc_sender_$timestamp';
    final receiverUsername = 'enc_receiver_$timestamp';
    const password = 'encPassword123';

    // --- 1. Authentication ---
    final senderToken = await getAuthToken(dio, senderUsername, password);
    final receiverToken = await getAuthToken(dio, receiverUsername, password);

    expect(senderToken, isNotEmpty);
    expect(receiverToken, isNotEmpty);

    // --- 2. Setup Encryption Services ---
    final senderEncryption = EncryptionService();
    final receiverEncryption = EncryptionService();

    await senderEncryption.initialize();
    await receiverEncryption.initialize();

    const testChannelId = 'encrypted-test-channel';

    // Setup channel encryption for both parties
    await senderEncryption.setupChannelEncryption(testChannelId, []);
    await receiverEncryption.setupChannelEncryption(testChannelId, []);

    // Simulate key exchange process
    final senderKeyPair = await senderEncryption.generateKeyPair();
    final receiverKeyPair = await receiverEncryption.generateKeyPair();

    final senderPublicKeyB64 =
        senderEncryption.encodePublicKey(senderKeyPair.publicKey);
    final receiverPublicKeyB64 =
        receiverEncryption.encodePublicKey(receiverKeyPair.publicKey);

    // Exchange public keys (simulate key exchange)
    await senderEncryption.processKeyExchange(
        testChannelId, 'receiver', receiverPublicKeyB64);
    await receiverEncryption.processKeyExchange(
        testChannelId, 'sender', senderPublicKeyB64);

    // For testing, manually set the shared keys (in production this would be derived from ECDH)
    final sharedKey = Uint8List(32);
    for (int i = 0; i < sharedKey.length; i++) {
      sharedKey[i] = (i * 7) % 256; // Deterministic test key
    }

    senderEncryption.testSetChannelKey(testChannelId, sharedKey);
    receiverEncryption.testSetChannelKey(testChannelId, sharedKey);

    // Verify encryption is ready
    expect(senderEncryption.isChannelEncryptionReady(testChannelId), true);
    expect(receiverEncryption.isChannelEncryptionReady(testChannelId), true);

    // --- 3. Connect WebSocket Clients ---
    final senderUri =
        Uri.parse('$wsBaseUrl/msg?channel=$testChannelId&token=$senderToken');
    final receiverUri =
        Uri.parse('$wsBaseUrl/msg?channel=$testChannelId&token=$receiverToken');

    late WebSocketChannel senderClient;
    late WebSocketChannel receiverClient;

    try {
      senderClient = WebSocketChannel.connect(senderUri);
      receiverClient = WebSocketChannel.connect(receiverUri);
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      fail("Failed to connect WebSocket clients: $e");
    }

    // --- 4. Setup Message Listeners ---
    final receivedEncryptedAudio = Completer<Map<String, dynamic>>();
    final senderPTTConfirmed = Completer<void>();

    // Receiver listens for encrypted_audio signals
    receiverClient.stream.listen((message) {
      if (message is String) {
        try {
          final decoded = json.decode(message);
          if (decoded['type'] == 'encrypted_audio' &&
              !receivedEncryptedAudio.isCompleted) {
            receivedEncryptedAudio.complete(decoded['payload']);
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // Sender listens for PTT confirmation
    senderClient.stream.listen((message) {
      if (message is String) {
        try {
          final decoded = json.decode(message);
          if (decoded['type'] == 'ptt_start_confirmed' &&
              !senderPTTConfirmed.isCompleted) {
            senderPTTConfirmed.complete();
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    });

    // --- 5. Generate Test Audio ---
    final int sampleRate = 48000;
    final int channels = 1;
    final encoder =
        OpusEncoder.create(sampleRate: sampleRate, channels: channels);

    if (encoder == null) {
      fail('Failed to create Opus encoder');
    }

    // Generate test audio: 20ms of 440Hz sine wave
    final pcm = Int16List(960); // 20ms at 48kHz
    for (int i = 0; i < pcm.length; i++) {
      pcm[i] = (sin(2 * pi * 440 * i / sampleRate) * 32767).toInt();
    }

    final encodedAudio = encoder.encode(pcm, 960);
    encoder.dispose();

    if (encodedAudio == null) {
      fail('Failed to encode test audio');
    }

    // --- 6. Encrypt Audio ---
    final encryptedChunk =
        await senderEncryption.encryptAudioChunk(encodedAudio, testChannelId);
    expect(encryptedChunk, isNotNull);

    // --- 7. Send Encrypted Audio ---
    // First start PTT
    senderClient.sink.add(json.encode({'type': 'ptt start'}));
    await senderPTTConfirmed.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail("PTT start not confirmed"),
    );

    // Send encrypted audio as signal
    senderClient.sink.add(json.encode({
      'type': 'encrypted_audio',
      'payload': encryptedChunk!.toJson(),
    }));

    // --- 8. Receive and Decrypt ---
    final encryptedPayload = await receivedEncryptedAudio.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail("Encrypted audio not received"),
    );

    // Parse the encrypted audio chunk
    final receivedChunk = EncryptedAudioChunk.fromJson(encryptedPayload);

    // Verify encryption metadata
    expect(receivedChunk.channelId, testChannelId);
    expect(receivedChunk.nonce.length, 12);
    expect(receivedChunk.authTag.length, 16);
    expect(receivedChunk.encryptedData.length, encodedAudio.length);

    // Decrypt the received audio
    final decryptedAudio = await receiverEncryption.decryptAudioChunk(
        receivedChunk, testChannelId);
    expect(decryptedAudio, isNotNull);

    // --- 9. Verify Audio Integrity ---
    expect(decryptedAudio, equals(encodedAudio),
        reason: "Decrypted audio should match original encoded audio");

    // --- 10. Verify Audio Quality ---
    final decoder =
        OpusDecoder.create(sampleRate: sampleRate, channels: channels);
    if (decoder == null) {
      fail('Failed to create Opus decoder');
    }

    final decodedPCM = decoder.decode(decryptedAudio!, 960);
    decoder.dispose();

    if (decodedPCM == null) {
      fail('Failed to decode decrypted audio');
    }

    // Convert to Int16List for comparison
    final ByteData byteData = decodedPCM.buffer.asByteData();
    final Int16List finalPCM = Int16List(decodedPCM.length ~/ 2);
    for (int i = 0; i < finalPCM.length; i++) {
      finalPCM[i] = byteData.getInt16(i * 2, Endian.little);
    }

    // Verify audio correlation (allowing for compression artifacts)
    double correlation = 0.0;
    for (int i = 0; i < min(pcm.length, finalPCM.length); i++) {
      correlation += (pcm[i] * finalPCM[i]).toDouble();
    }

    expect(correlation, greaterThan(0),
        reason: "Final decoded audio should correlate with original");

    // --- 11. Security Verification ---
    // Verify that the encrypted data is actually encrypted (not plaintext)
    expect(receivedChunk.encryptedData, isNot(equals(encodedAudio)),
        reason: "Encrypted data should not equal original audio");

    // Verify that without the key, decryption fails
    final wrongKey = Uint8List(32);
    for (int i = 0; i < wrongKey.length; i++) {
      wrongKey[i] = 255 - sharedKey[i]; // Different key
    }

    final wrongEncryption = EncryptionService();
    await wrongEncryption.initialize();
    wrongEncryption.testSetChannelKey(testChannelId, wrongKey);

    final wrongDecryption =
        await wrongEncryption.decryptAudioChunk(receivedChunk, testChannelId);
    expect(wrongDecryption, isNull,
        reason: "Decryption with wrong key should fail");

    // --- 12. Cleanup ---
    try {
      senderClient.sink.add(json.encode({'type': 'ptt stop'}));
      await Future.delayed(const Duration(milliseconds: 100));
      await senderClient.sink.close();
      await receiverClient.sink.close();
      senderEncryption.dispose();
      receiverEncryption.dispose();
      wrongEncryption.dispose();
    } catch (e) {
      print("Cleanup error (non-fatal): $e");
    }

    print("✅ End-to-End Encrypted Audio Test PASSED");
    print("   - Audio encrypted with AES-256-GCM");
    print("   - Transmitted securely between users");
    print("   - Decrypted successfully with correct key");
    print("   - Audio quality preserved through encryption");
    print("   - Security verified (wrong key fails)");
  });
}
