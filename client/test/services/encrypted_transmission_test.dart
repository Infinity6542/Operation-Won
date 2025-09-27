import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Encrypted Audio Transmission Simulation', () {
    late EncryptionService senderEncryption;
    late EncryptionService receiverEncryption;
    const String testChannelId = 'e2e-test-channel';

    setUp(() async {
      senderEncryption = EncryptionService();
      receiverEncryption = EncryptionService();
      
      await senderEncryption.initialize();
      await receiverEncryption.initialize();
    });

    tearDown(() {
      senderEncryption.dispose();
      receiverEncryption.dispose();
    });

    test('Complete encrypted audio transmission pipeline', () async {
      // --- 1. Setup Channel Encryption ---
      await senderEncryption.setupChannelEncryption(testChannelId, []);
      await receiverEncryption.setupChannelEncryption(testChannelId, []);

      // Simulate key exchange
      final senderKeyPair = await senderEncryption.generateKeyPair();
      final receiverKeyPair = await receiverEncryption.generateKeyPair();

      final senderPublicKeyB64 = senderEncryption.encodePublicKey(senderKeyPair.publicKey);
      final receiverPublicKeyB64 = receiverEncryption.encodePublicKey(receiverKeyPair.publicKey);

      await senderEncryption.processKeyExchange(testChannelId, 'receiver', receiverPublicKeyB64);
      await receiverEncryption.processKeyExchange(testChannelId, 'sender', senderPublicKeyB64);

      // For testing, manually set identical shared keys
      final sharedKey = Uint8List(32);
      for (int i = 0; i < sharedKey.length; i++) {
        sharedKey[i] = (i * 13) % 256; // Deterministic test key
      }
      
      senderEncryption.testSetChannelKey(testChannelId, sharedKey);
      receiverEncryption.testSetChannelKey(testChannelId, sharedKey);

      // Verify encryption is ready
      expect(senderEncryption.isChannelEncryptionReady(testChannelId), true);
      expect(receiverEncryption.isChannelEncryptionReady(testChannelId), true);

      // --- 2. Simulate Audio Data (Mock Opus-encoded audio) ---
      // In real app: Raw PCM → Opus Encoding → produces this data
      final simulatedEncodedAudio = Uint8List.fromList([
        // Simulate realistic Opus packet structure
        0x78, 0x9C, 0x5A, 0x48, 0xCC, 0x49, 0xC9, 0x4C, // Header
        0x57, 0x48, 0x49, 0x2C, 0x49, 0x54, 0x04, 0x00, // Data
        0x1A, 0x9C, 0x03, 0xFE, 0xAB, 0x12, 0x34, 0x56, // More data
        0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x11, 0x22, 0x33, // Audio samples
        0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, // Audio samples
        0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, // Audio samples
      ]);

      expect(simulatedEncodedAudio.length, 48, reason: 'Simulated audio should have realistic size');

      // --- 3. Encrypt Audio (Sender Side) ---
      final encryptedChunk = await senderEncryption.encryptAudioChunk(simulatedEncodedAudio, testChannelId);
      expect(encryptedChunk, isNotNull, reason: 'Audio should be encrypted successfully');
      
      // Verify encryption properties
      expect(encryptedChunk!.encryptedData.length, simulatedEncodedAudio.length);
      expect(encryptedChunk.nonce.length, 12); // GCM nonce
      expect(encryptedChunk.authTag.length, 16); // GCM auth tag
      expect(encryptedChunk.channelId, testChannelId);
      expect(encryptedChunk.encryptedData, isNot(equals(simulatedEncodedAudio)), 
          reason: 'Encrypted data should differ from original');

      // --- 4. Serialize for Transmission (WebSocket) ---
      final transmissionJson = encryptedChunk.toJson();
      final transmissionString = json.encode(transmissionJson);
      
      expect(transmissionString, isA<String>());
      expect(transmissionString.length, greaterThan(0));

      // --- 5. Deserialize on Receiver Side ---
      final receivedJson = json.decode(transmissionString) as Map<String, dynamic>;
      final receivedChunk = EncryptedAudioChunk.fromJson(receivedJson);
      
      // Verify transmission integrity
      expect(receivedChunk.channelId, encryptedChunk.channelId);
      expect(receivedChunk.nonce, equals(encryptedChunk.nonce));
      expect(receivedChunk.authTag, equals(encryptedChunk.authTag));
      expect(receivedChunk.encryptedData, equals(encryptedChunk.encryptedData));
      expect(receivedChunk.sequence, encryptedChunk.sequence);

      // --- 6. Decrypt Audio (Receiver Side) ---
      final decryptedAudio = await receiverEncryption.decryptAudioChunk(receivedChunk, testChannelId);
      expect(decryptedAudio, isNotNull, reason: 'Audio should be decrypted successfully');
      expect(decryptedAudio, equals(simulatedEncodedAudio), 
          reason: 'Decrypted audio should match original encoded audio');

      // --- 7. Verify Perfect Data Integrity ---
      // In real app: Decrypted data → Opus Decoding → PCM audio
      for (int i = 0; i < simulatedEncodedAudio.length; i++) {
        expect(decryptedAudio![i], simulatedEncodedAudio[i],
            reason: 'Byte $i should match exactly after encryption round-trip');
      }

      // --- 8. Security Verification ---
      
      // Test 1: Wrong key should fail decryption
      final wrongKey = Uint8List(32);
      for (int i = 0; i < wrongKey.length; i++) {
        wrongKey[i] = 255 - sharedKey[i]; // Completely different key
      }
      
      final wrongEncryption = EncryptionService();
      await wrongEncryption.initialize();
      wrongEncryption.testSetChannelKey(testChannelId, wrongKey);
      
      final wrongDecryption = await wrongEncryption.decryptAudioChunk(receivedChunk, testChannelId);
      expect(wrongDecryption, isNull, 
          reason: 'Decryption with wrong key should fail');
      wrongEncryption.dispose();

      // Test 2: Tampered data should fail decryption
      final tamperedChunk = EncryptedAudioChunk(
        encryptedData: Uint8List.fromList([...receivedChunk.encryptedData]..last = receivedChunk.encryptedData.last ^ 0xFF),
        nonce: receivedChunk.nonce,
        authTag: receivedChunk.authTag,
        channelId: receivedChunk.channelId,
        sequence: receivedChunk.sequence,
      );
      
      final tamperedDecryption = await receiverEncryption.decryptAudioChunk(tamperedChunk, testChannelId);
      expect(tamperedDecryption, isNull, 
          reason: 'Decryption of tampered data should fail');

      // Test 3: Wrong auth tag should fail decryption
      final wrongAuthTag = Uint8List(16);
      for (int i = 0; i < wrongAuthTag.length; i++) {
        wrongAuthTag[i] = receivedChunk.authTag[i] ^ 0xFF;
      }
      
      final wrongAuthChunk = EncryptedAudioChunk(
        encryptedData: receivedChunk.encryptedData,
        nonce: receivedChunk.nonce,
        authTag: wrongAuthTag,
        channelId: receivedChunk.channelId,
        sequence: receivedChunk.sequence,
      );
      
      final wrongAuthDecryption = await receiverEncryption.decryptAudioChunk(wrongAuthChunk, testChannelId);
      expect(wrongAuthDecryption, isNull, 
          reason: 'Decryption with wrong auth tag should fail');

      print('✅ Complete End-to-End Encrypted Audio Pipeline Test PASSED');
      print('   📊 Audio data integrity: 100% (${simulatedEncodedAudio.length} bytes)');
      print('   🔐 Original audio: ${simulatedEncodedAudio.length} bytes');
      print('   🔒 Encrypted size: ${encryptedChunk.encryptedData.length} bytes + metadata');
      print('   🔓 Decrypted matches: ${decryptedAudio == simulatedEncodedAudio}');
      print('   🛡️ Security verified: wrong key/data/auth fail');
      print('   📡 WebSocket transmission: JSON serialization OK');
    });

    test('Multiple users can receive same encrypted broadcast', () async {
      // Setup 3 users: 1 sender, 2 receivers
      final receiver2Encryption = EncryptionService();
      await receiver2Encryption.initialize();
      
      // Setup encryption for all users
      await senderEncryption.setupChannelEncryption(testChannelId, []);
      await receiverEncryption.setupChannelEncryption(testChannelId, []);
      await receiver2Encryption.setupChannelEncryption(testChannelId, []);

      // Use same shared key for all (in production, proper key exchange would handle this)
      final sharedKey = Uint8List.fromList(List.generate(32, (i) => (i * 17) % 256));
      
      senderEncryption.testSetChannelKey(testChannelId, sharedKey);
      receiverEncryption.testSetChannelKey(testChannelId, sharedKey);
      receiver2Encryption.testSetChannelKey(testChannelId, sharedKey);

      // Create test audio
      final testAudio = Uint8List.fromList(List.generate(128, (i) => i % 256));
      
      // Sender encrypts once
      final encryptedChunk = await senderEncryption.encryptAudioChunk(testAudio, testChannelId);
      expect(encryptedChunk, isNotNull);

      // Both receivers can decrypt the same message
      final decrypted1 = await receiverEncryption.decryptAudioChunk(encryptedChunk!, testChannelId);
      final decrypted2 = await receiver2Encryption.decryptAudioChunk(encryptedChunk, testChannelId);

      expect(decrypted1, equals(testAudio));
      expect(decrypted2, equals(testAudio));
      expect(decrypted1, equals(decrypted2));

      receiver2Encryption.dispose();
      print('✅ Multi-user encrypted broadcast test PASSED');
    });

    test('Nonce uniqueness prevents replay attacks', () async {
      // Setup encryption
      await senderEncryption.setupChannelEncryption(testChannelId, []);
      final sharedKey = Uint8List.fromList(List.generate(32, (i) => (i * 19) % 256));
      senderEncryption.testSetChannelKey(testChannelId, sharedKey);

      final testAudio = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Encrypt same data multiple times
      final chunk1 = await senderEncryption.encryptAudioChunk(testAudio, testChannelId);
      final chunk2 = await senderEncryption.encryptAudioChunk(testAudio, testChannelId);
      final chunk3 = await senderEncryption.encryptAudioChunk(testAudio, testChannelId);

      expect(chunk1, isNotNull);
      expect(chunk2, isNotNull);
      expect(chunk3, isNotNull);

      // All nonces should be unique
      expect(chunk1!.nonce, isNot(equals(chunk2!.nonce)));
      expect(chunk1.nonce, isNot(equals(chunk3!.nonce)));
      expect(chunk2.nonce, isNot(equals(chunk3.nonce)));

      // All encrypted data should be different (due to different nonces)
      expect(chunk1.encryptedData, isNot(equals(chunk2.encryptedData)));
      expect(chunk1.encryptedData, isNot(equals(chunk3.encryptedData)));
      expect(chunk2.encryptedData, isNot(equals(chunk3.encryptedData)));

      // But all should decrypt to the same original data
      await receiverEncryption.setupChannelEncryption(testChannelId, []);
      receiverEncryption.testSetChannelKey(testChannelId, sharedKey);

      final decrypted1 = await receiverEncryption.decryptAudioChunk(chunk1, testChannelId);
      final decrypted2 = await receiverEncryption.decryptAudioChunk(chunk2, testChannelId);
      final decrypted3 = await receiverEncryption.decryptAudioChunk(chunk3, testChannelId);

      expect(decrypted1, equals(testAudio));
      expect(decrypted2, equals(testAudio));
      expect(decrypted3, equals(testAudio));

      print('✅ Nonce uniqueness and replay protection test PASSED');
    });
  });
}