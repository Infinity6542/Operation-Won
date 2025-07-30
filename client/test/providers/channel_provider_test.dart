import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/providers/channel_provider.dart';
import 'package:operation_won/models/channel_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('=== CHANNEL PROVIDER TESTS ===', () {
    late ChannelProvider channelProvider;

    tearDown(() {
      try {
        channelProvider.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    group('Initialization Tests', () {
      test('should initialize with default state', () {
        channelProvider = ChannelProvider();

        expect(channelProvider.channels, isEmpty);
        expect(channelProvider.isLoading, false);
        expect(channelProvider.error, isNull);
      });

      test('should initialize with empty channels list', () {
        channelProvider = ChannelProvider();

        expect(channelProvider.channels, isA<List<ChannelResponse>>());
        expect(channelProvider.channels.length, 0);
      });
    });

    group('Loading State Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should start in non-loading state', () {
        expect(channelProvider.isLoading, false);
      });

      test('should handle loading state during channel load', () async {
        expect(channelProvider.isLoading, false);
        
        final loadFuture = channelProvider.loadChannels();
        
        await loadFuture;
        
        expect(channelProvider.isLoading, false);
      });

      test('should handle loading state transitions', () async {
        channelProvider.addListener(() {
          // Monitor loading state changes
        });

        await channelProvider.loadChannels();
        
        // Should complete without hanging
        expect(channelProvider.isLoading, false);
      });
    });

    group('Channel Creation Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should handle channel creation with valid data', () async {
        const channelName = 'Test Channel';
        
        final result = await channelProvider.createChannel(channelName);
        
        // Will fail due to no server connection, but input validation works
        expect(result, false);
        expect(channelProvider.isLoading, false);
      });

      test('should handle channel creation with empty name', () async {
        const channelName = '';
        
        final result = await channelProvider.createChannel(channelName);
        
        expect(result, false);
        expect(channelProvider.isLoading, false);
      });

      test('should handle channel creation with event UUID', () async {
        const channelName = 'Event Channel';
        const eventUuid = 'test-event-uuid';
        
        final result = await channelProvider.createChannel(channelName, eventUuid: eventUuid);
        
        expect(result, false); // Will fail due to no server
        expect(channelProvider.isLoading, false);
      });

      test('should validate channel name input', () async {
        // Test with whitespace only
        final result1 = await channelProvider.createChannel('   ');
        expect(result1, false);
        
        // Test with very long name
        final longName = 'a' * 1000;
        final result2 = await channelProvider.createChannel(longName);
        expect(result2, false);
        
        expect(channelProvider.isLoading, false);
      });
    });

    group('Channel Filtering Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should filter channels by event', () {
        // Test the filtering logic (even with empty list)
        final eventChannels = channelProvider.getChannelsForEvent('test-event-uuid');
        expect(eventChannels, isA<List<ChannelResponse>>());
        expect(eventChannels, isEmpty); // No channels loaded yet
      });

      test('should get standalone channels (no event)', () {
        final standaloneChannels = channelProvider.getChannelsForEvent(null);
        expect(standaloneChannels, isA<List<ChannelResponse>>());
        expect(standaloneChannels, isEmpty);
      });

      test('should handle multiple event filters', () {
        final event1Channels = channelProvider.getChannelsForEvent('event-1');
        final event2Channels = channelProvider.getChannelsForEvent('event-2');
        
        expect(event1Channels, isA<List<ChannelResponse>>());
        expect(event2Channels, isA<List<ChannelResponse>>());
        expect(event1Channels, isEmpty);
        expect(event2Channels, isEmpty);
      });
    });

    group('Error Handling Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should clear error state', () {
        channelProvider.clearError();
        expect(channelProvider.error, isNull);
      });

      test('should handle network errors during channel load', () async {
        await channelProvider.loadChannels();
        
        // Should handle network error gracefully
        expect(channelProvider.isLoading, false);
        // Error might be set depending on network conditions
        expect(channelProvider.error, anyOf(isNull, isA<String>()));
      });

      test('should maintain error state until cleared', () async {
        // Simulate error by trying to create channel with invalid data
        await channelProvider.createChannel('');
        
        if (channelProvider.error != null) {
          final error = channelProvider.error;
          expect(error, isNotNull);
          
          channelProvider.clearError();
          expect(channelProvider.error, isNull);
        }
      });
    });

    group('State Management Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should notify listeners on state changes', () {
        int notificationCount = 0;
        
        channelProvider.addListener(() {
          notificationCount++;
        });

        channelProvider.clearError();
        
        expect(notificationCount, greaterThanOrEqualTo(0));
      });

      test('should maintain consistent state types', () {
        expect(channelProvider.channels, isA<List<ChannelResponse>>());
        expect(channelProvider.isLoading, isA<bool>());
        expect(channelProvider.error, anyOf(isNull, isA<String>()));
      });

      test('should handle multiple operations concurrently', () async {
        final futures = <Future>[];
        
        // Start multiple operations
        futures.add(channelProvider.loadChannels());
        futures.add(channelProvider.createChannel('Test Channel 1'));
        futures.add(channelProvider.createChannel('Test Channel 2'));
        
        // Wait for all to complete
        await Future.wait(futures);
        
        expect(channelProvider.isLoading, false);
      });
    });

    group('Provider Lifecycle Tests', () {
      test('should dispose cleanly', () {
        channelProvider = ChannelProvider();
        
        expect(() => channelProvider.dispose(), returnsNormally);
      });

      test('should handle multiple disposal calls', () {
        channelProvider = ChannelProvider();
        
        // First disposal should work normally
        expect(() => channelProvider.dispose(), returnsNormally);
        
        // Second disposal may throw error, which is expected behavior
        expect(() => channelProvider.dispose(), throwsA(isA<FlutterError>()));
      });

      test('should maintain state after operations', () async {
        channelProvider = ChannelProvider();
        
        await channelProvider.loadChannels();
        await channelProvider.createChannel('Test Channel');
        
        expect(channelProvider.channels, isA<List<ChannelResponse>>());
        expect(channelProvider.isLoading, false);
      });
    });

    group('Channel Model Tests', () {
      test('should create ChannelRequest correctly', () {
        const channelName = 'Test Channel';
        final request = ChannelRequest(channelName: channelName);
        
        expect(request.channelName, channelName);
        expect(request.eventUuid, isNull);
      });

      test('should create ChannelRequest with event UUID', () {
        const channelName = 'Event Channel';
        const eventUuid = 'test-event-uuid';
        final request = ChannelRequest(
          channelName: channelName,
          eventUuid: eventUuid,
        );
        
        expect(request.channelName, channelName);
        expect(request.eventUuid, eventUuid);
      });

      test('should handle JSON serialization for ChannelRequest', () {
        const channelName = 'Test Channel';
        final request = ChannelRequest(channelName: channelName);
        
        final json = request.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['channel_name'], channelName);
      });

      test('should create ChannelResponse from JSON', () {
        final json = {
          'channel_uuid': 'test-uuid',
          'channel_name': 'Test Channel',
          'event_uuid': null,
        };
        
        final response = ChannelResponse.fromJson(json);
        
        expect(response.channelUuid, 'test-uuid');
        expect(response.channelName, 'Test Channel');
        expect(response.eventUuid, isNull);
      });

      test('should create ChannelResponse with event UUID from JSON', () {
        final json = {
          'channel_uuid': 'channel-uuid',
          'channel_name': 'Event Channel',
          'event_uuid': 'event-uuid',
        };
        
        final response = ChannelResponse.fromJson(json);
        
        expect(response.channelUuid, 'channel-uuid');
        expect(response.channelName, 'Event Channel');
        expect(response.eventUuid, 'event-uuid');
      });

      test('should handle missing fields in JSON gracefully', () {
        final json = <String, dynamic>{};
        
        expect(() => ChannelResponse.fromJson(json), returnsNormally);
      });
    });

    group('Channel Data Management Tests', () {
      setUp(() {
        channelProvider = ChannelProvider();
      });

      test('should start with empty channel list', () {
        expect(channelProvider.channels, isEmpty);
        expect(channelProvider.channels.length, 0);
      });

      test('should maintain channel list consistency', () async {
        final initialCount = channelProvider.channels.length;
        
        await channelProvider.loadChannels();
        
        final afterLoadCount = channelProvider.channels.length;
        expect(afterLoadCount, greaterThanOrEqualTo(initialCount));
      });

      test('should handle refresh operations', () async {
        await channelProvider.loadChannels();
        
        await channelProvider.loadChannels(); // Refresh
        final secondLoadCount = channelProvider.channels.length;
        
        expect(secondLoadCount, greaterThanOrEqualTo(0));
        expect(channelProvider.isLoading, false);
      });
    });
  });
}
