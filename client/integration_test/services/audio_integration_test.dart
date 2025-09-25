import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_opus/flutter_opus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Opus encode/decode round-trip over Go WebSocket server',
      (WidgetTester tester) async {
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

    // Create Opus encoder
    final encoder = OpusEncoder.create(
      sampleRate: sampleRate,
      channels: channels,
    );

    if (encoder == null) {
      fail('Failed to create Opus encoder');
    }

    final Uint8List? encoded = encoder.encode(pcm, samples);
    encoder.dispose();

    if (encoded == null) {
      fail('Failed to encode audio data');
    }

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

    // Create Opus decoder
    final decoder = OpusDecoder.create(
      sampleRate: sampleRate,
      channels: channels,
    );

    if (decoder == null) {
      fail('Failed to create Opus decoder');
    }

    final Uint8List? decoded = decoder.decode(echoed, samples);
    decoder.dispose();

    if (decoded == null) {
      fail('Failed to decode audio data');
    }

    // Convert decoded bytes back to Int16List for comparison
    final ByteData byteData = decoded.buffer.asByteData();
    final Int16List decodedInt16 = Int16List(decoded.length ~/ 2);
    for (int i = 0; i < decodedInt16.length; i++) {
      decodedInt16[i] = byteData.getInt16(i * 2, Endian.little);
    }

    // Compare original and decoded (allow some error due to lossy compression)
    double mse = 0;
    for (int i = 0; i < min(pcm.length, decodedInt16.length); i++) {
      mse += pow(pcm[i] - decodedInt16[i], 2);
    }
    mse /= min(pcm.length, decodedInt16.length);
    print('Mean squared error: $mse');
    expect(mse < 1000, true,
        reason: 'Decoded audio should be similar to original');
  });
}
