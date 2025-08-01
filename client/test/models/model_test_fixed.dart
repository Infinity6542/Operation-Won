import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/models/auth_model.dart';
import 'package:operation_won/models/channel_model.dart';
import 'package:operation_won/models/event_model.dart';

void main() {
  group('=== MODEL TESTS ===', () {
    group('Auth Model Tests', () {
      group('AuthRequest Tests', () {
        test('should create AuthRequest with email and password', () {
          final request = AuthRequest(
            email: 'test@example.com',
            password: 'password123',
          );

          expect(request.email, 'test@example.com');
          expect(request.password, 'password123');
          expect(request.username, isNull);
        });

        test('should create AuthRequest with username, email and password', () {
          final request = AuthRequest(
            username: 'testuser',
            email: 'test@example.com',
            password: 'password123',
          );

          expect(request.username, 'testuser');
          expect(request.email, 'test@example.com');
          expect(request.password, 'password123');
        });

        test('should serialize to JSON correctly without username', () {
          final request = AuthRequest(
            email: 'test@example.com',
            password: 'password123',
          );

          final json = request.toJson();

          expect(json['email'], 'test@example.com');
          expect(json['password'], 'password123');
          expect(json.containsKey('username'), false);
        });

        test('should serialize to JSON correctly with username', () {
          final request = AuthRequest(
            username: 'testuser',
            email: 'test@example.com',
            password: 'password123',
          );

          final json = request.toJson();

          expect(json['username'], 'testuser');
          expect(json['email'], 'test@example.com');
          expect(json['password'], 'password123');
        });

        test('should handle empty values', () {
          final request = AuthRequest(
            email: '',
            password: '',
          );

          expect(request.email, '');
          expect(request.password, '');
          expect(request.username, isNull);
        });
      });

      group('AuthResponse Tests', () {
        test('should create AuthResponse with token', () {
          final response = AuthResponse(
            token: 'sample-jwt-token',
            message: 'Login successful',
          );

          expect(response.token, 'sample-jwt-token');
          expect(response.message, 'Login successful');
        });

        test('should create AuthResponse from JSON', () {
          final json = {
            'token': 'jwt-token-from-json',
            'message': 'Registration successful',
          };

          final response = AuthResponse.fromJson(json);

          expect(response.token, 'jwt-token-from-json');
          expect(response.message, 'Registration successful');
        });

        test('should handle missing token in JSON', () {
          final json = {
            'message': 'Message without token',
          };

          final response = AuthResponse.fromJson(json);

          expect(response.token, isNull);
          expect(response.message, 'Message without token');
        });

        test('should handle missing message in JSON', () {
          final json = {
            'token': 'token-without-message',
          };

          final response = AuthResponse.fromJson(json);

          expect(response.token, 'token-without-message');
          expect(response.message, isNull);
        });

        test('should handle empty JSON', () {
          final json = <String, dynamic>{};

          final response = AuthResponse.fromJson(json);

          expect(response.token, isNull);
          expect(response.message, isNull);
        });

        test('should create AuthResponse with null values', () {
          final response = AuthResponse(
            token: null,
            message: null,
          );

          expect(response.token, isNull);
          expect(response.message, isNull);
        });
      });
    });

    group('Channel Model Tests', () {
      group('ChannelRequest Tests', () {
        test('should create ChannelRequest with channel name only', () {
          final request = ChannelRequest(channelName: 'General');

          expect(request.channelName, 'General');
          expect(request.eventUuid, isNull);
        });

        test('should create ChannelRequest with channel name and event UUID',
            () {
          final request = ChannelRequest(
            channelName: 'Event Channel',
            eventUuid: 'event-uuid-123',
          );

          expect(request.channelName, 'Event Channel');
          expect(request.eventUuid, 'event-uuid-123');
        });

        test('should serialize to JSON correctly without event UUID', () {
          final request = ChannelRequest(channelName: 'Simple Channel');

          final json = request.toJson();

          expect(json['channel_name'], 'Simple Channel');
          expect(json['event_uuid'], isNull);
        });

        test('should serialize to JSON correctly with event UUID', () {
          final request = ChannelRequest(
            channelName: 'Event Channel',
            eventUuid: 'event-123',
          );

          final json = request.toJson();

          expect(json['channel_name'], 'Event Channel');
          expect(json['event_uuid'], 'event-123');
        });

        test('should handle empty channel name', () {
          final request = ChannelRequest(channelName: '');

          expect(request.channelName, '');
          expect(request.eventUuid, isNull);
        });
      });

      group('ChannelResponse Tests', () {
        test('should create ChannelResponse from JSON', () {
          final json = {
            'channel_uuid': 'channel-uuid-456',
            'channel_name': 'Response Channel',
            'event_uuid': 'event-uuid-789',
          };

          final response = ChannelResponse.fromJson(json);

          expect(response.channelUuid, 'channel-uuid-456');
          expect(response.channelName, 'Response Channel');
          expect(response.eventUuid, 'event-uuid-789');
        });

        test('should create ChannelResponse with event UUID from JSON', () {
          final json = {
            'channel_uuid': 'standalone-channel',
            'channel_name': 'Standalone Channel',
          };

          final response = ChannelResponse.fromJson(json);

          expect(response.channelUuid, 'standalone-channel');
          expect(response.channelName, 'Standalone Channel');
          expect(response.eventUuid, isNull);
        });

        test('should handle missing fields in JSON gracefully', () {
          final json = <String, dynamic>{};

          final response = ChannelResponse.fromJson(json);

          expect(response.channelUuid, equals(''));
          expect(response.channelName, equals(''));
          expect(response.eventUuid, isNull);
        });

        test('should handle null values in JSON', () {
          final json = {
            'channel_uuid': null,
            'channel_name': null,
            'event_uuid': null,
          };

          final response = ChannelResponse.fromJson(json);

          expect(response.channelUuid, equals(''));
          expect(response.channelName, equals(''));
          expect(response.eventUuid, isNull);
        });

        test('should serialize channel response to JSON', () {
          final response = ChannelResponse(
            channelUuid: 'uuid-123',
            channelName: 'Test Channel',
            eventUuid: 'event-456',
          );

          final json = response.toJson();

          expect(json['channel_uuid'], 'uuid-123');
          expect(json['channel_name'], 'Test Channel');
          expect(json['event_uuid'], 'event-456');
        });

        test('should handle partial JSON data', () {
          final json = {
            'channel_name': 'Partial Channel',
          };

          final response = ChannelResponse.fromJson(json);

          expect(response.channelName, 'Partial Channel');
          expect(response.channelUuid, equals(''));
          expect(response.eventUuid, isNull);
        });
      });
    });

    group('Event Model Tests', () {
      group('EventRequest Tests', () {
        test('should create EventRequest with name and description', () {
          final request = EventRequest(
            eventName: 'Test Event',
            eventDescription: 'This is a test event',
          );

          expect(request.eventName, 'Test Event');
          expect(request.eventDescription, 'This is a test event');
        });

        test('should create EventRequest with name only', () {
          final request = EventRequest(eventName: 'Simple Event');

          expect(request.eventName, 'Simple Event');
          expect(request.eventDescription, '');
        });

        test('should serialize to JSON correctly', () {
          final request = EventRequest(
            eventName: 'JSON Event',
            eventDescription: 'Event for JSON testing',
          );

          final json = request.toJson();

          expect(json['event_name'], 'JSON Event');
          expect(json['event_description'], 'Event for JSON testing');
        });

        test('should serialize to JSON with empty description', () {
          final request = EventRequest(eventName: 'No Description Event');

          final json = request.toJson();

          expect(json['event_name'], 'No Description Event');
          expect(json['event_description'], '');
        });

        test('should handle empty event name', () {
          final request = EventRequest(eventName: '');

          expect(request.eventName, '');
          expect(request.eventDescription, '');
        });

        test('should handle long event name and description', () {
          final longName = 'A' * 500;
          final longDescription = 'B' * 2000;

          final request = EventRequest(
            eventName: longName,
            eventDescription: longDescription,
          );

          expect(request.eventName.length, 500);
          expect(request.eventDescription.length, 2000);
        });
      });

      group('EventResponse Tests', () {
        test('should create EventResponse from JSON', () {
          final json = {
            'event_uuid': 'event-response-uuid',
            'event_name': 'Response Event',
            'event_description': 'Event from response',
            'is_organiser': true,
          };

          final response = EventResponse.fromJson(json);

          expect(response.eventUuid, 'event-response-uuid');
          expect(response.eventName, 'Response Event');
          expect(response.eventDescription, 'Event from response');
          expect(response.isOrganiser, true);
        });

        test('should create EventResponse with participant role', () {
          final json = {
            'event_uuid': 'participant-event',
            'event_name': 'Participant Event',
            'event_description': 'Event for participants',
            'is_organiser': false,
          };

          final response = EventResponse.fromJson(json);

          expect(response.eventUuid, 'participant-event');
          expect(response.eventName, 'Participant Event');
          expect(response.eventDescription, 'Event for participants');
          expect(response.isOrganiser, false);
        });

        test('should handle missing fields in JSON gracefully', () {
          final json = <String, dynamic>{};

          final response = EventResponse.fromJson(json);

          expect(response.eventUuid, equals(''));
          expect(response.eventName, equals(''));
          expect(response.eventDescription, equals(''));
          expect(response.isOrganiser, false);
        });

        test('should handle null values in JSON', () {
          final json = {
            'event_uuid': null,
            'event_name': null,
            'event_description': null,
            'is_organiser': null,
          };

          final response = EventResponse.fromJson(json);

          expect(response.eventUuid, equals(''));
          expect(response.eventName, equals(''));
          expect(response.eventDescription, equals(''));
          expect(response.isOrganiser, false);
        });

        test('should serialize event response to JSON', () {
          final response = EventResponse(
            eventUuid: 'uuid-789',
            eventName: 'Serialized Event',
            eventDescription: 'Description for serialization',
            isOrganiser: true,
            createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
            updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
          );

          final json = response.toJson();

          expect(json['event_uuid'], 'uuid-789');
          expect(json['event_name'], 'Serialized Event');
          expect(json['event_description'], 'Description for serialization');
          expect(json['is_organiser'], true);
        });

        test('should handle partial JSON data', () {
          final json = {
            'event_name': 'Partial Event',
            'is_organiser': false,
          };

          final response = EventResponse.fromJson(json);

          expect(response.eventName, 'Partial Event');
          expect(response.isOrganiser, false);
          expect(response.eventUuid, equals(''));
          expect(response.eventDescription, equals(''));
        });

        test('should handle boolean conversion for is_organiser', () {
          // Test with valid boolean values
          final json1 = {
            'event_uuid': 'event-bool-test',
            'event_name': 'Boolean Test',
            'event_description': 'Testing boolean conversion',
            'is_organiser': true,
          };

          final response1 = EventResponse.fromJson(json1);
          expect(response1.eventName, 'Boolean Test');
          expect(response1.isOrganiser, true);

          // Test with false boolean
          final json2 = {
            'event_uuid': 'event-bool-test-2',
            'event_name': 'Boolean Test 2',
            'event_description': 'Testing boolean conversion',
            'is_organiser': false,
          };

          final response2 = EventResponse.fromJson(json2);
          expect(response2.isOrganiser, false);
        });
      });
    });

    group('Model Integration Tests', () {
      test('should handle complex data structures', () {
        // Test that models can handle real-world JSON data
        final complexAuthJson = {
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
          'message': 'Authentication successful',
        };

        final complexChannelJson = {
          'channel_uuid': 'ch_12345_abcdef',
          'channel_name': 'Emergency Response Team Alpha',
          'event_uuid': 'evt_67890_ghijkl',
        };

        final complexEventJson = {
          'event_uuid': 'evt_67890_ghijkl',
          'event_name': 'Emergency Response Training Exercise',
          'event_description':
              'Multi-day training exercise for emergency response protocols including communication procedures, evacuation routes, and coordination with local authorities.',
          'is_organiser': true,
        };

        expect(() => AuthResponse.fromJson(complexAuthJson), returnsNormally);
        expect(() => ChannelResponse.fromJson(complexChannelJson),
            returnsNormally);
        expect(() => EventResponse.fromJson(complexEventJson), returnsNormally);
      });

        test('should maintain data integrity through serialization', () {
        // Test round-trip serialization
        final originalEvent = EventResponse(
          eventUuid: 'test-uuid',
          eventName: 'Test Event',
          eventDescription: 'Test Description',
          isOrganiser: true,
          createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
          updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        );        final json = originalEvent.toJson();
        final deserializedEvent = EventResponse.fromJson(json);

        expect(deserializedEvent.eventUuid, originalEvent.eventUuid);
        expect(deserializedEvent.eventName, originalEvent.eventName);
        expect(
            deserializedEvent.eventDescription, originalEvent.eventDescription);
        expect(deserializedEvent.isOrganiser, originalEvent.isOrganiser);
      });

      test('should handle malformed JSON gracefully', () {
        final malformedJsons = [
          {'unexpected_field': 'value'},
          {'channel_name': 'valid_string'}, // Missing required fields
          {'is_organiser': false}, // Missing required fields
          {}, // Empty
        ];

        for (final json in malformedJsons) {
          expect(
              () => ChannelResponse.fromJson(Map<String, dynamic>.from(json)),
              returnsNormally);
          expect(() => EventResponse.fromJson(Map<String, dynamic>.from(json)),
              returnsNormally);
          expect(() => AuthResponse.fromJson(Map<String, dynamic>.from(json)),
              returnsNormally);
        }
      });
    });

    group('Model Edge Cases', () {
      test('should handle Unicode characters', () {
        final unicodeRequest = EventRequest(
          eventName: '🚨 Emergency Training 응급 상황 🚨',
          eventDescription:
              'Training with Unicode: français, español, 中文, العربية',
        );

        final json = unicodeRequest.toJson();
        expect(json['event_name'], contains('🚨'));
        expect(json['event_description'], contains('français'));
      });

      test('should handle extremely long strings', () {
        final veryLongName = 'A' * 10000;
        final veryLongDescription = 'B' * 50000;

        final request = EventRequest(
          eventName: veryLongName,
          eventDescription: veryLongDescription,
        );

        expect(request.eventName.length, 10000);
        expect(request.eventDescription.length, 50000);
      });

      test('should handle special characters in JSON', () {
        final specialJson = {
          'event_name': 'Event "with" quotes & <tags>',
          'event_description': 'Description\nwith\nnewlines\tand\ttabs',
          'channel_name': 'Channel\\with\\backslashes',
        };

        expect(() => EventResponse.fromJson(specialJson), returnsNormally);
        expect(() => ChannelResponse.fromJson(specialJson), returnsNormally);
      });
    });
  });
}
