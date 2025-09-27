import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_opus/flutter_opus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Opus Integration Tests (Android)', () {
    testWidgets('should initialize Opus encoder and decoder on Android',
        (WidgetTester tester) async {
      OpusEncoder? encoder;
      OpusDecoder? decoder;

      try {
        // Test version info
        final version = OpusDecoder.getVersion();
        expect(version, isNotNull);
        expect(version, isNotEmpty);
        debugPrint('✅ Opus version on Android: $version');

        // Create encoder and decoder
        encoder = OpusEncoder.create(
          sampleRate: 48000,
          channels: 1,
        );
        decoder = OpusDecoder.create(
          sampleRate: 48000,
          channels: 1,
        );

        expect(encoder, isNotNull,
            reason: 'Opus encoder should be created on Android');
        expect(decoder, isNotNull,
            reason: 'Opus decoder should be created on Android');

        debugPrint(
            '✅ Opus encoder and decoder created successfully on Android');
      } catch (e) {
        debugPrint('❌ Opus initialization failed on Android: $e');
        rethrow;
      } finally {
        encoder?.dispose();
        decoder?.dispose();
      }
    });

    testWidgets('should encode and decode audio on Android',
        (WidgetTester tester) async {
      OpusEncoder? encoder;
      OpusDecoder? decoder;

      try {
        encoder = OpusEncoder.create(sampleRate: 48000, channels: 1)!;
        decoder = OpusDecoder.create(sampleRate: 48000, channels: 1)!;

        // Generate test audio (20ms frame - common for voice)
        const int frameSize = 960; // 20ms at 48kHz
        final pcmData = Int16List(frameSize);

        // Generate sine wave at 440Hz
        for (int i = 0; i < frameSize; i++) {
          final double time = i / 48000.0;
          pcmData[i] = (16000 * sin(2 * pi * 440 * time)).round();
        }

        // Encode
        final encodedData = encoder.encode(pcmData, frameSize);
        expect(encodedData, isNotNull,
            reason: 'Encoded data should not be null');
        expect(encodedData!.length, greaterThan(0),
            reason: 'Encoded data should have content');

        debugPrint(
            '✅ Android Opus encode: ${pcmData.length} samples → ${encodedData.length} bytes');

        // Decode
        final decodedData = decoder.decode(encodedData, frameSize);
        expect(decodedData, isNotNull,
            reason: 'Decoded data should not be null');
        expect(decodedData!.length, greaterThan(0),
            reason: 'Decoded data should have content');

        debugPrint(
            '✅ Android Opus decode: ${encodedData.length} bytes → ${decodedData.length} samples');

        // Verify reasonable compression
        final originalBytes = pcmData.length * 2; // 16-bit = 2 bytes per sample
        final compressionRatio = originalBytes / encodedData.length;
        expect(compressionRatio, greaterThan(2),
            reason: 'Should achieve at least 2:1 compression');

        debugPrint(
            '✅ Android Opus compression ratio: ${compressionRatio.toStringAsFixed(1)}:1');
      } catch (e) {
        debugPrint('❌ Android Opus encode/decode test failed: $e');
        rethrow;
      } finally {
        encoder?.dispose();
        decoder?.dispose();
      }
    });

    testWidgets('should handle multiple frame sizes on Android',
        (WidgetTester tester) async {
      OpusEncoder? encoder;
      OpusDecoder? decoder;

      try {
        encoder = OpusEncoder.create(sampleRate: 48000, channels: 1)!;
        decoder = OpusDecoder.create(sampleRate: 48000, channels: 1)!;

        // Test different frame sizes commonly used in voice apps
        const List<int> frameSizes = [480, 960, 1920]; // 10ms, 20ms, 40ms

        for (final frameSize in frameSizes) {
          final pcmData = Int16List(frameSize);

          // Generate test tone
          for (int i = 0; i < frameSize; i++) {
            pcmData[i] = (8000 * sin(2 * pi * i / frameSize * 4)).round();
          }

          final encoded = encoder.encode(pcmData, frameSize);
          final decoded = decoder.decode(encoded!, frameSize);

          expect(encoded, isNotNull,
              reason: 'Frame size $frameSize encode failed');
          expect(decoded, isNotNull,
              reason: 'Frame size $frameSize decode failed');

          final efficiency = (frameSize * 2) / encoded.length;
          debugPrint(
              '✅ Android frame ${frameSize}: efficiency ${efficiency.toStringAsFixed(1)}:1');
        }
      } catch (e) {
        debugPrint('❌ Android multi-frame test failed: $e');
        rethrow;
      } finally {
        encoder?.dispose();
        decoder?.dispose();
      }
    });

    testWidgets('should demonstrate voice quality compression on Android',
        (WidgetTester tester) async {
      OpusEncoder? encoder;
      OpusDecoder? decoder;

      try {
        encoder = OpusEncoder.create(sampleRate: 48000, channels: 1)!;
        decoder = OpusDecoder.create(sampleRate: 48000, channels: 1)!;

        // Simulate realistic voice pattern (200ms of speech)
        const int totalFrames = 10; // 10 * 20ms = 200ms
        const int frameSize = 960; // 20ms at 48kHz
        int totalOriginalBytes = 0;
        int totalCompressedBytes = 0;

        for (int frame = 0; frame < totalFrames; frame++) {
          final pcmData = Int16List(frameSize);

          // Simulate voice with fundamental frequency around 150Hz + harmonics
          for (int i = 0; i < frameSize; i++) {
            final double t = (frame * frameSize + i) / 48000.0;
            final double voice = 6000 * sin(2 * pi * 150 * t) + // Fundamental
                3000 * sin(2 * pi * 300 * t) + // 2nd harmonic
                1500 * sin(2 * pi * 450 * t); // 3rd harmonic

            pcmData[i] = voice.round().clamp(-32767, 32767);
          }

          final encoded = encoder.encode(pcmData, frameSize);
          final decoded = decoder.decode(encoded!, frameSize);

          totalOriginalBytes += frameSize * 2; // 16-bit samples
          totalCompressedBytes += encoded.length;

          expect(encoded, isNotNull);
          expect(decoded, isNotNull);
        }

        final overallRatio = totalOriginalBytes / totalCompressedBytes;
        debugPrint('✅ Android voice compression test:');
        debugPrint('   Original: ${totalOriginalBytes} bytes (200ms voice)');
        debugPrint('   Compressed: ${totalCompressedBytes} bytes');
        debugPrint('   Overall ratio: ${overallRatio.toStringAsFixed(1)}:1');

        expect(overallRatio, greaterThan(4),
            reason: 'Voice should compress well (>4:1)');
      } catch (e) {
        debugPrint('❌ Android voice compression test failed: $e');
        rethrow;
      } finally {
        encoder?.dispose();
        decoder?.dispose();
      }
    });
  });
}
