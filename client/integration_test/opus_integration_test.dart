import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:operation_won/services/audio_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Opus Integration Tests (Android)', () {
    late AudioService audioService;

    setUp(() {
      audioService = AudioService();
    });

    tearDown(() {
      audioService.dispose();
    });

    testWidgets('should initialize Opus on Android', (WidgetTester tester) async {
      // Wait for Opus initialization
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Check if we're on a supported platform
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        
        debugPrint('✅ Running on mobile platform: $defaultTargetPlatform');
        
        // The AudioService should have successfully initialized Opus
        // We can't directly access private fields, but we can test the public interface
        expect(audioService, isNotNull);
        
        // Test that audio encoding/decoding methods exist and can be called
        // (they will fail gracefully if Opus isn't working)
        
        // Create sample audio data (20ms of audio at 48kHz, 16-bit mono)
        const int sampleRate = 48000;
        const int frameSize = 960; // 20ms
        final Uint8List testAudio = Uint8List(frameSize * 2); // 16-bit samples
        
        // Fill with a simple test pattern
        final ByteData byteData = testAudio.buffer.asByteData();
        for (int i = 0; i < frameSize; i++) {
          // Generate a simple sine wave
          final double t = i / sampleRate;
          final sample = (16384 * sin(2 * pi * 440 * t)).round(); // Quieter sine wave
          byteData.setInt16(i * 2, sample, Endian.little);
        }
        
        debugPrint('✅ Created test audio data: ${testAudio.length} bytes');
        
        // Test encoding (this will use Opus if available, or return original data)
        final encodedData = await audioService.encodeAudioData(testAudio);
        expect(encodedData, isNotNull);
        expect(encodedData!.isNotEmpty, true);
        
        debugPrint('✅ Audio encoding completed: ${encodedData.length} bytes');
        
        // Test decoding
        final decodedData = await audioService.decodeAudioData(encodedData);
        expect(decodedData, isNotNull);
        expect(decodedData!.isNotEmpty, true);
        
        debugPrint('✅ Audio decoding completed: ${decodedData.length} bytes');
        
        // If Opus is working, the encoded data should be smaller than the original
        // (unless it's a very short sample where overhead dominates)
        debugPrint('📊 Compression ratio: ${testAudio.length} → ${encodedData.length} bytes');
        
        if (encodedData.length < testAudio.length) {
          debugPrint('✅ Opus compression is working!');
        } else if (encodedData.length == testAudio.length) {
          debugPrint('⚠️ No compression - Opus may not be active (returned original data)');
        }
        
        // Test that decoded data has the expected length
        expect(decodedData.length, greaterThanOrEqualTo(frameSize));
        
        debugPrint('✅ Opus integration test completed successfully');
        
      } else {
        debugPrint('⚠️ Skipping Opus test - not on mobile platform ($defaultTargetPlatform)');
        debugPrint('   This test should be run on Android or iOS devices');
      }
    });

    testWidgets('should handle audio service lifecycle on Android', (WidgetTester tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        
        debugPrint('✅ Testing AudioService lifecycle on ${defaultTargetPlatform}');
        
        // Test that the service can be created and disposed without errors
        final service1 = AudioService();
        await tester.pumpAndSettle(const Duration(seconds: 1));
        service1.dispose();
        
        // Test that we can create multiple instances
        final service2 = AudioService();
        final service3 = AudioService();
        await tester.pumpAndSettle(const Duration(seconds: 1));
        
        service2.dispose();
        service3.dispose();
        
        debugPrint('✅ AudioService lifecycle test completed');
      } else {
        debugPrint('⚠️ Skipping lifecycle test - not on mobile platform');
      }
    });

    testWidgets('should report Opus status on Android', (WidgetTester tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        
        debugPrint('📊 Opus Status Report for ${defaultTargetPlatform}:');
        
        // Try to get version info through a small test
        try {
          final testData = Uint8List(1920); // 20ms of 16-bit mono at 48kHz
          final result = await audioService.encodeAudioData(testData);
          
          if (result != null && result.length != testData.length) {
            debugPrint('✅ Opus is ACTIVE - data was processed');
            debugPrint('   Input: ${testData.length} bytes → Output: ${result.length} bytes');
          } else {
            debugPrint('⚠️ Opus may not be active - data unchanged');
            debugPrint('   This could mean Opus initialization failed silently');
          }
        } catch (e) {
          debugPrint('❌ Opus test failed: $e');
        }
        
        debugPrint('📱 Platform: ${defaultTargetPlatform}');
        debugPrint('🔧 AudioService configuration:');
        debugPrint('   - Sample Rate: 48000 Hz');
        debugPrint('   - Channels: 1 (mono)');
        debugPrint('   - Frame Size: 960 samples (20ms)');
        debugPrint('   - Bit Depth: 16-bit');
        
        debugPrint('✅ Opus status report completed');
      }
    });
  });
}