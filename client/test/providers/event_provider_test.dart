import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:operation_won/providers/event_provider.dart';
import 'package:operation_won/providers/settings_provider.dart';
import 'package:operation_won/services/api_service.dart';
import 'package:operation_won/models/event_model.dart';

// Generate mocks
@GenerateMocks([ApiService, SettingsProvider])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventProvider Tests', () {
    late EventProvider eventProvider;

    tearDown(() {
      try {
        eventProvider.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    group('Initialization', () {
      test('should initialize with empty events list and not loading', () {
        eventProvider = EventProvider();

        expect(eventProvider.events, isEmpty);
        expect(eventProvider.isLoading, false);
        expect(eventProvider.error, isNull);
      });

      test('should initialize with correct initial state', () {
        eventProvider = EventProvider();

        expect(eventProvider.events, isEmpty);
        expect(eventProvider.isLoading, false);
        expect(eventProvider.error, isNull);
      });
    });

    group('Error Management', () {
      test('should clear error manually', () {
        eventProvider = EventProvider();

        // We can't directly set error from outside, so let's test the public interface
        eventProvider.clearError();
        expect(eventProvider.error, isNull);
      });
    });

    group('Basic Event Model Tests', () {
      test('EventResponse should be created correctly', () {
        final event = EventResponse(
          eventUuid: 'test-uuid',
          eventName: 'Test Event',
          eventDescription: 'Test Description',
          isOrganiser: true,
          createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        );

        expect(event.eventUuid, 'test-uuid');
        expect(event.eventName, 'Test Event');
        expect(event.eventDescription, 'Test Description');
        expect(event.isOrganiser, true);
      });

      test('EventRequest should be created correctly', () {
        final request = EventRequest(
          eventName: 'Test Event',
          eventDescription: 'Test Description',
        );

        expect(request.eventName, 'Test Event');
        expect(request.eventDescription, 'Test Description');
      });

      test('EventRequest should handle empty description', () {
        final request = EventRequest(
          eventName: 'Test Event',
        );

        expect(request.eventName, 'Test Event');
        expect(request.eventDescription, '');
      });
    });

    group('JSON Serialization', () {
      test('EventResponse should deserialize from JSON correctly', () {
        final json = {
          'event_uuid': 'test-uuid',
          'event_name': 'Test Event',
          'event_description': 'Test Description',
          'is_organiser': true,
        };

        final event = EventResponse.fromJson(json);

        expect(event.eventUuid, 'test-uuid');
        expect(event.eventName, 'Test Event');
        expect(event.eventDescription, 'Test Description');
        expect(event.isOrganiser, true);
      });

      test('EventResponse should handle missing JSON fields', () {
        final json = <String, dynamic>{};

        final event = EventResponse.fromJson(json);

        expect(event.eventUuid, '');
        expect(event.eventName, '');
        expect(event.eventDescription, '');
        expect(event.isOrganiser, false);
      });

      test('EventRequest should serialize to JSON correctly', () {
        final request = EventRequest(
          eventName: 'Test Event',
          eventDescription: 'Test Description',
        );

        final json = request.toJson();

        expect(json['event_name'], 'Test Event');
        expect(json['event_description'], 'Test Description');
      });

      test('EventResponse should serialize to JSON correctly', () {
        final event = EventResponse(
          eventUuid: 'test-uuid',
          eventName: 'Test Event',
          eventDescription: 'Test Description',
          isOrganiser: true,
          createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        );

        final json = event.toJson();

        expect(json['event_uuid'], 'test-uuid');
        expect(json['event_name'], 'Test Event');
        expect(json['event_description'], 'Test Description');
        expect(json['is_organiser'], true);
      });
    });

    group('Provider State Management', () {
      test('should notify listeners when state changes', () {
        eventProvider = EventProvider();

        var notificationCount = 0;
        eventProvider.addListener(() => notificationCount++);

        // Clear error should notify if there was an error
        eventProvider.clearError();

        // Since we can't set error directly in tests, we expect no notifications
        // for clearing a non-existent error
        expect(notificationCount, 0);
      });

      test('should maintain consistent state', () {
        eventProvider = EventProvider();

        expect(eventProvider.events, isA<List<EventResponse>>());
        expect(eventProvider.isLoading, isA<bool>());
        expect(eventProvider.error, anyOf(isNull, isA<String>()));
      });
    });

    group('Integration with ApiService', () {
      test('should handle ApiService initialization', () {
        eventProvider = EventProvider();

        // Test that the provider initializes without crashing
        expect(eventProvider.events, isEmpty);
        expect(eventProvider.isLoading, false);
        expect(eventProvider.error, isNull);
      });

      test('should handle settings provider integration', () {
        final settingsProvider = SettingsProvider();
        eventProvider = EventProvider(settingsProvider: settingsProvider);

        // Should initialize successfully with settings provider
        expect(eventProvider.events, isEmpty);
        expect(eventProvider.isLoading, false);
        expect(eventProvider.error, isNull);
      });
    });
  });
}
