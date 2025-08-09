import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Opus encode/decode round-trip over Go WebSocket server',
      (WidgetTester tester) async {
    // Initialize Opus
    initOpus(await opus_flutter.load());

    // Generate synthetic PCM audio (sine wave)
    final int sampleRate = 48000;
    final int channels = 1;
    final int durationMs = 100; // 100ms
    final int samples = (sampleRate * durationMs ~/ 1000) * channels;
    final double freq = 440.0; // A4
    final Int16List pcm = Int16List(samples);
    for (int i = 0; i < samples; i++) {
      pcm[i] = (sin(2 * pi * freq * i / sampleRate) * 32767).toInt();
    }

    // Encode with Opus
    final encoder = SimpleOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: Application.voip,
    );
    final Uint8List encoded = encoder.encode(input: pcm);
    encoder.destroy();

    // Connect to Go WebSocket server
    final channel =
        WebSocketChannel.connect(Uri.parse('ws://10.0.2.2:8000/msg'));
    channel.sink.add(encoded);

    // Wait for echo response
    final completer = Completer<Uint8List>();
    channel.stream.listen((message) {
      if (message is Uint8List) {
        completer.complete(message);
      } else if (message is List<int>) {
        completer.complete(Uint8List.fromList(message));
      }
    });
    final Uint8List echoed =
        await completer.future.timeout(Duration(seconds: 5));

    // Decode with Opus
    final decoder = SimpleOpusDecoder(
      sampleRate: sampleRate,
      channels: channels,
    );
    final Int16List decoded = decoder.decode(input: echoed);
    decoder.destroy();

    // Compare original and decoded (allow some error due to lossy compression)
    double mse = 0;
    for (int i = 0; i < min(pcm.length, decoded.length); i++) {
      mse += pow(pcm[i] - decoded[i], 2);
    }
    mse /= min(pcm.length, decoded.length);
    print('Mean squared error: $mse');
    expect(mse < 1000, true,
        reason: 'Decoded audio should be similar to original');
  });
}
