import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'providers/auth_provider_test.dart' as auth_provider_tests;
import 'providers/channel_provider_test.dart' as channel_provider_tests;
import 'providers/event_provider_test.dart' as event_provider_tests;
import 'providers/settings_provider_test.dart' as settings_provider_tests;
import 'widgets/widget_test.dart' as widget_tests;
import 'models/model_test.dart' as model_tests;

void main() {
  group('=== OPERATION WON FLUTTER CLIENT TEST SUITE ===', () {
    
    // Provider Tests
    group('🎯 PROVIDER TESTS', () {
      group('AuthProvider', auth_provider_tests.main);
      group('ChannelProvider', channel_provider_tests.main);
      group('EventProvider', event_provider_tests.main);
      group('SettingsProvider', settings_provider_tests.main);
    });

    // Widget Tests
    group('🎨 WIDGET TESTS', () {
      group('UI Components', widget_tests.main);
    });

    // Model Tests
    group('📊 MODEL TESTS', () {
      group('Data Models', model_tests.main);
    });

    // Note: AudioService and CommunicationService tests are excluded
    // because they require native plugin implementations that aren't
    // available in the test environment. These would be tested with
    // integration tests on real devices.
    
    // Future test categories to be added:
    // - Service Tests (API, WebSocket, Audio, Communication)
    // - Integration Tests (Provider + Service interactions)
    // - UI Integration Tests (Widget + Provider interactions)
    // - Performance Tests (Memory usage, rendering performance)
    // - Accessibility Tests (Screen reader compatibility)
  });
}
