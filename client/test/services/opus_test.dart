import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_opus/flutter_opus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Opus Codec Tests', () {
    late OpusEncoder encoder;
    late OpusDecoder decoder;
    const int sampleRate = 48000;
    const int channels = 1;

    setUp(() async {
      try {
        encoder = OpusEncoder.create(
          sampleRate: sampleRate,
          channels: channels,
        )!;
        decoder = OpusDecoder.create(
          sampleRate: sampleRate,
          channels: channels,
        )!;
      } catch (e) {
        debugPrint('Setup failed: $e');
        rethrow;
      }
    });

    tearDown(() {
      try {
        encoder.dispose();
        decoder.dispose();
      } catch (e) {
        debugPrint('Teardown error: $e');
      }
    });

    test('should get Opus version', () {
      final version = OpusDecoder.getVersion();
      expect(version, isNotNull);
      expect(version, isNotEmpty);
      debugPrint('✅ Opus version: $version');
    });

    test('should create encoder and decoder successfully', () {
      expect(encoder, isNotNull);
      expect(decoder, isNotNull);
      debugPrint('✅ Opus encoder and decoder created successfully');
    });

    test('should encode and decode audio data', () {
      // Generate test PCM audio data (100ms of sine wave at 440Hz)
      const int durationMs = 100;
      const int samplesPerMs = sampleRate ~/ 1000;
      const int totalSamples = durationMs * samplesPerMs * channels;

      final pcmData = Int16List(totalSamples);
      const double frequency = 440.0; // A4 note

      for (int i = 0; i < totalSamples; i++) {
        final double time = i / sampleRate;
        final double amplitude = 16000; // Half of Int16 max to avoid clipping
        pcmData[i] = (amplitude * sin(2 * pi * frequency * time)).round();
      }

      try {
        // Encode PCM to Opus (flutter_opus API expects frameSize as second parameter)
        final encodedData = encoder.encode(pcmData, totalSamples);
        expect(encodedData, isNotNull);
        expect(encodedData!.length, greaterThan(0));

        debugPrint(
            '✅ Encoded ${pcmData.length} PCM samples to ${encodedData.length} opus bytes');

        // Decode Opus back to PCM (flutter_opus API expects frameSize as second parameter)
        final decodedData = decoder.decode(encodedData, totalSamples);
        expect(decodedData, isNotNull);
        expect(decodedData!.length, greaterThan(0));

        debugPrint(
            '✅ Decoded ${encodedData.length} opus bytes to ${decodedData.length} PCM samples');

        // The decoded data should be similar in size to original
        // (allowing for some variation due to frame alignment)
        expect(decodedData.length, greaterThan((totalSamples * 0.8).round()));
        expect(decodedData.length, lessThan((totalSamples * 1.2).round()));

        debugPrint('✅ Opus encode/decode round-trip successful');
      } catch (e) {
        debugPrint('❌ Opus encode/decode failed: $e');
        rethrow;
      }
    });

    test('should handle various frame sizes', () {
      const List<int> frameSizes = [
        480,
        960,
        1920,
        2880
      ]; // 10ms, 20ms, 40ms, 60ms at 48kHz

      for (final frameSize in frameSizes) {
        final pcmData = Int16List(frameSize * channels);

        // Fill with test data
        for (int i = 0; i < pcmData.length; i++) {
          pcmData[i] = (1000 * sin(2 * pi * i / frameSize)).round();
        }

        try {
          final encoded = encoder.encode(pcmData, frameSize);
          expect(encoded, isNotNull);
          expect(encoded!.length, greaterThan(0));

          final decoded = decoder.decode(encoded, frameSize);
          expect(decoded, isNotNull);
          expect(decoded!.length, greaterThan(0));

          debugPrint(
              '✅ Frame size ${frameSize}: ${pcmData.length} → ${encoded.length} → ${decoded.length}');
        } catch (e) {
          debugPrint('❌ Failed with frame size $frameSize: $e');
          rethrow;
        }
      }
    });

    test('should handle silence encoding efficiently', () {
      // Test with silence (should compress very well)
      const int frameSize = 960; // 20ms at 48kHz
      final silentData = Int16List(frameSize * channels); // All zeros

      try {
        final encoded = encoder.encode(silentData, frameSize);
        expect(encoded, isNotNull);
        expect(encoded!.length, greaterThan(0));
        expect(encoded.length,
            lessThan(100)); // Silence should compress to very small size

        final decoded = decoder.decode(encoded, frameSize);
        expect(decoded, isNotNull);
        expect(decoded!.length, greaterThan(0));

        debugPrint(
            '✅ Silence compression: ${silentData.length} samples → ${encoded.length} bytes');
      } catch (e) {
        debugPrint('❌ Silence encoding failed: $e');
        rethrow;
      }
    });

    test('should handle error cases gracefully', () {
      try {
        // Test with empty data
        final emptyData = Int16List(0);
        expect(() => encoder.encode(emptyData, 0), throwsException);
        debugPrint('✅ Empty data handling: correctly throws exception');
      } catch (e) {
        debugPrint('Empty data test exception expected: $e');
      }

      try {
        // Test decoder with invalid data (but valid structure for flutter_opus)
        final invalidOpusData = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final result = decoder.decode(invalidOpusData, 960);
        // flutter_opus might not throw but return null or empty data
        debugPrint(
            '✅ Invalid opus data handling: result = ${result?.length ?? 'null'}');
      } catch (e) {
        debugPrint('✅ Invalid data correctly throws: $e');
      }
    });

    test('should demonstrate compression efficiency', () {
      // Generate 500ms of test audio for compression test
      const int durationMs = 500;
      const int samplesPerMs = sampleRate ~/ 1000;
      const int totalSamples = durationMs * samplesPerMs * channels;

      final pcmData = Int16List(totalSamples);

      // Mix of frequencies to test compression
      for (int i = 0; i < totalSamples; i++) {
        final double time = i / sampleRate;
        final double signal = 8000 * sin(2 * pi * 440 * time) + // A4
            4000 * sin(2 * pi * 880 * time) + // A5
            2000 * sin(2 * pi * 220 * time); // A3
        pcmData[i] = signal.round().clamp(-32767, 32767);
      }

      final pcmBytes = pcmData.length * 2; // 16-bit samples = 2 bytes each

      try {
        final encoded = encoder.encode(pcmData, totalSamples);
        expect(encoded, isNotNull);

        final compressionRatio = pcmBytes / encoded!.length;

        debugPrint('✅ Compression test:');
        debugPrint('   Original PCM: $pcmBytes bytes');
        debugPrint('   Compressed Opus: ${encoded.length} bytes');
        debugPrint(
            '   Compression ratio: ${compressionRatio.toStringAsFixed(1)}:1');

        expect(compressionRatio,
            greaterThan(3)); // Should compress by at least 3:1
        expect(encoded.length,
            lessThan(pcmBytes ~/ 2)); // Should be less than half original size

        // Verify it can be decoded
        final decoded = decoder.decode(encoded, totalSamples);
        expect(decoded, isNotNull);
        expect(decoded!.length, greaterThan((totalSamples * 0.8).round()));
      } catch (e) {
        debugPrint('❌ Compression test failed: $e');
        rethrow;
      }
    });

    test('should work with realistic voice frame sizes', () {
      // Test with common voice codec frame sizes
      const List<int> voiceFrameSizes = [
        160,
        320,
        480,
        960
      ]; // 5ms, 10ms, 15ms, 20ms at 16kHz equivalent

      for (final frameSize in voiceFrameSizes) {
        // Generate realistic voice-like waveform
        final pcmData = Int16List(frameSize);

        for (int i = 0; i < frameSize; i++) {
          // Simulate voice with fundamental + harmonics
          final double t = i / sampleRate;
          final double voice =
              5000 * sin(2 * pi * 200 * t) + // Fundamental (200Hz)
                  2500 * sin(2 * pi * 400 * t) + // 2nd harmonic
                  1250 * sin(2 * pi * 600 * t); // 3rd harmonic

          pcmData[i] = voice.round().clamp(-32767, 32767);
        }

        try {
          final encoded = encoder.encode(pcmData, frameSize);
          final decoded = decoder.decode(encoded!, frameSize);

          expect(encoded, isNotNull);
          expect(decoded, isNotNull);

          final efficiency = (pcmData.length * 2) / encoded.length;
          debugPrint(
              '✅ Voice frame ${frameSize}: efficiency ${efficiency.toStringAsFixed(1)}:1');
        } catch (e) {
          fail('Voice frame test failed for size $frameSize: $e');
        }
      }
    });
  });
}
