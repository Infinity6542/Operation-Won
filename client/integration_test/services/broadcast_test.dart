import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:web_socket_channel/web_socket_channel.dart';

// --- Test Configuration ---
const String serverBaseUrl =
    String.fromEnvironment('SERVER_URL', defaultValue: 'http://localhost:8000');
const String wsBaseUrl =
    String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8000/');
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

  testWidgets('WebSocket broadcast test with authentication',
      (WidgetTester tester) async {
    final dio = Dio();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final senderUsername = 'sender_$timestamp';
    final receiverUsername = 'receiver_$timestamp';
    const password = 'password123';

    // --- 1. Get Auth Tokens ---
    final senderToken = await getAuthToken(dio, senderUsername, password);
    final receiverToken = await getAuthToken(dio, receiverUsername, password);

    expect(senderToken, isNotEmpty,
        reason: "Sender token should not be empty.");
    expect(receiverToken, isNotEmpty,
        reason: "Receiver token should not be empty.");

    // --- 2. Initialize Opus ---
    initOpus(await opus_flutter.load());

    // --- 3. Connect Clients ---
    final channelId = 'broadcast-test-$timestamp';

    final senderUri =
        Uri.parse('$wsBaseUrl/msg?channel=$channelId&token=$senderToken');
    final receiverUri =
        Uri.parse('$wsBaseUrl/msg?channel=$channelId&token=$receiverToken');

    late WebSocketChannel senderClient;
    late WebSocketChannel receiverClient;

    try {
      senderClient = WebSocketChannel.connect(senderUri);
      receiverClient = WebSocketChannel.connect(receiverUri);

      // Wait a moment for connections to establish
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      fail("Failed to connect WebSocket clients: $e");
    }

    // --- 4. Listen for Messages ---
    final receiverCompleter = Completer<Uint8List>();
    receiverClient.stream.listen((message) {
      if (message is List<int> && !receiverCompleter.isCompleted) {
        // This is the audio data we are waiting for
        receiverCompleter.complete(Uint8List.fromList(message));
      }
    }, onError: (e) => fail("Receiver client encountered an error: $e"));

    bool senderReceivedMessage = false;
    final senderConfirmationCompleter = Completer<void>();
    senderClient.stream.listen((message) {
      try {
        final decoded = json.decode(message);
        if (decoded['type'] == 'ptt_start_confirmed') {
          senderConfirmationCompleter.complete();
        }
      } catch (e) {
        // This is expected to be the binary message echo, which we are checking against
        senderReceivedMessage = true;
      }
    }, onError: (e) => fail("Sender client encountered an error: $e"));

    // --- 5. Generate and Send Message ---
    final int sampleRate = 48000;
    final int channels = 1;
    final encoder = SimpleOpusEncoder(
        sampleRate: sampleRate,
        channels: channels,
        application: Application.voip);
    final pcm = Int16List(960); // 20ms of audio
    for (int i = 0; i < pcm.length; i++) {
      pcm[i] = (sin(2 * pi * 440 * i / sampleRate) * 32767).toInt();
    }
    final encodedMessage = encoder.encode(input: pcm);
    encoder.destroy();

    // Give connections a moment to establish
    await Future.delayed(const Duration(milliseconds: 500));

    // --- 5a. Send PTT Start and wait for confirmation ---
    senderClient.sink.add(json.encode({'type': 'ptt start'}));

    await senderConfirmationCompleter.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail("Sender did not receive PTT start confirmation."),
    );

    // --- 5b. Send Audio Data ---
    senderClient.sink.add(encodedMessage);

    // --- 6. Verify Results ---
    final receivedMessage = await receiverCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail("Receiver did not get the message in time."),
    );

    expect(receivedMessage, equals(encodedMessage),
        reason: "Received message should match the sent message.");

    // --- 6a. Verify Audio Quality by Decoding ---
    final decoder =
        SimpleOpusDecoder(sampleRate: sampleRate, channels: channels);
    try {
      final decodedPcm = decoder.decode(input: receivedMessage);
      expect(decodedPcm.length, equals(960),
          reason: "Decoded PCM should have 960 samples (20ms at 48kHz)");

      // Verify the decoded audio is similar to original (allowing for compression artifacts)
      double correlation = 0.0;
      for (int i = 0; i < decodedPcm.length; i++) {
        correlation += (pcm[i] * decodedPcm[i]).toDouble();
      }
      expect(correlation, greaterThan(0),
          reason: "Decoded audio should correlate with original");
    } finally {
      decoder.destroy();
    }

    await Future.delayed(const Duration(milliseconds: 500));
    expect(senderReceivedMessage, isFalse,
        reason: "Sender should not receive its own message.");

    // --- 7. Cleanup ---
    try {
      senderClient.sink.add(json.encode({'type': 'ptt stop'}));
      await Future.delayed(const Duration(milliseconds: 100));
      await senderClient.sink.close();
      await receiverClient.sink.close();
    } catch (e) {
      // Ignore cleanup errors
      print("Cleanup error (non-fatal): $e");
    }
  });
}
