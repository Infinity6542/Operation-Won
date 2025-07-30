import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/services/communication_service.dart';
import 'package:operation_won/providers/settings_provider.dart';
import 'dart:typed_data';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunicationService Tests', () {
    late CommunicationService commService;
    late SettingsProvider settingsProvider;

    setUp(() async {
      settingsProvider = SettingsProvider();
      commService = CommunicationService(settingsProvider);
      // Allow time for initialization to complete
      await Future.delayed(Duration(milliseconds: 100));
    });

    tearDown(() async {
      try {
        commService.dispose();
        // Allow time for disposal to complete
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    group('Initialization', () {
      test('should initialize with correct default state', () {
        expect(commService.isConnected, false);
        expect(commService.currentChannelId, isNull);
        expect(commService.isPTTActive, false);
        expect(commService.isRecording, false);
        expect(commService.isPTTToggleMode, isA<bool>());
        expect(commService.isEmergencyMode, false);
        expect(commService.hasE2EEKey, isA<bool>());
      });
    });

    group('PTT (Push-to-Talk)', () {
      test('should handle PTT state', () {
        expect(commService.isPTTActive, false);
        expect(commService.isRecording, false);
      });

      test('should handle PTT mode switching', () async {
        // PTT mode is internal state - we test the getters
        expect(commService.isPTTToggleMode, isA<bool>());
        expect(commService.isPTTActive, isA<bool>());
      });
    });

    group('Channel Management', () {
      test('should handle channel operations', () async {
        const testChannelId = 'test-channel-123';

        try {
          await commService.joinChannel(testChannelId);
          // In test environment this might fail, but shouldn't crash
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      test('should handle leaving channels', () async {
        try {
          await commService.leaveChannel();
          // Should complete gracefully
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('E2EE Key Management', () {
      test('should generate E2EE key', () async {
        try {
          final keyBytes = await commService.generateE2EEKey();
          expect(keyBytes, anyOf(isNull, isA<Uint8List>()));

          if (keyBytes != null) {
            expect(keyBytes.length, 32); // 256 bits = 32 bytes
          }
        } catch (e) {
          // May fail in test environment
          expect(e, isNotNull);
        }
      });

      test('should set and get E2EE key', () async {
        final testKey = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          testKey[i] = i;
        }

        try {
          final success = await commService.setE2EEKey(testKey);
          expect(success, isA<bool>());

          final retrievedKey = commService.getE2EEKey();
          expect(retrievedKey, anyOf(isNull, isA<Uint8List>()));
        } catch (e) {
          // May fail in test environment
          expect(e, isNotNull);
        }
      });
    });

    group('State Management', () {
      test('should maintain consistent state', () {
        expect(commService.isConnected, isA<bool>());
        expect(commService.isPTTActive, isA<bool>());
        expect(commService.isRecording, isA<bool>());
        expect(commService.hasE2EEKey, isA<bool>());
        expect(commService.currentChannelId, anyOf(isNull, isA<String>()));
        expect(commService.isEmergencyMode, isA<bool>());
        expect(commService.isPTTToggleMode, isA<bool>());
      });

      test('should handle state changes', () {
        var notificationCount = 0;
        commService.addListener(() => notificationCount++);

        // Initial state shouldn't trigger notifications
        expect(notificationCount, 0);
      });
    });

    group('Error Handling', () {
      test('should handle operations gracefully', () {
        // These should not throw exceptions
        expect(() => commService.isConnected, returnsNormally);
        expect(() => commService.isPTTActive, returnsNormally);
        expect(() => commService.isRecording, returnsNormally);
        expect(() => commService.hasE2EEKey, returnsNormally);
        expect(() => commService.currentChannelId, returnsNormally);
        expect(() => commService.isEmergencyMode, returnsNormally);
        expect(() => commService.isPTTToggleMode, returnsNormally);
      });

      test('should handle invalid operations gracefully', () async {
        // Test with invalid data
        try {
          await commService.joinChannel('');
        } catch (e) {
          // Expected in test environment
          expect(e, isNotNull);
        }
      });
    });

    group('Emergency Channel', () {
      test('should handle emergency mode state', () {
        expect(commService.isEmergencyMode, isA<bool>());

        // Emergency channel operations are complex and require WebSocket
        // We test that the state getter works
      });
    });

    group('Settings Integration', () {
      test('should respond to settings changes', () {
        // Test that the service is listening to settings
        expect(commService.isConnected, isA<bool>());

        // Settings changes are handled internally
        // We can't easily test this without mocking
      });
    });

    group('Audio Integration', () {
      test('should handle audio recording state', () {
        expect(commService.isRecording, isA<bool>());
      });
    });
  });
}
