import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'providers/event_provider_test.dart' as event_provider_tests;

void main() {
  group('Operation Won Test Suite', () {
    group('EventProvider Tests', event_provider_tests.main);

    // Note: AudioService and CommunicationService tests are excluded
    // because they require native plugin implementations that aren't
    // available in the test environment. These would be tested with
    // integration tests on real devices.
  });
}
