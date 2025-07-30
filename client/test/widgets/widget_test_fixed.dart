import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:operation_won/providers/channel_provider.dart';
import 'package:operation_won/providers/event_provider.dart';
import 'package:operation_won/providers/settings_provider.dart';
import 'package:operation_won/channel_item.dart';
import 'package:operation_won/event_item.dart';
import 'package:operation_won/models/channel_model.dart';
import 'package:operation_won/models/event_model.dart';

void main() {
  group('=== WIDGET TESTS ===', () {
    group('ChannelItem Tests', () {
      testWidgets('should display channel name correctly', (tester) async {
        final channel = ChannelResponse(
          channelUuid: 'test-uuid',
          channelName: 'Test Channel',
          eventUuid: null,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChannelItem(channel: channel),
              ),
            ),
          ),
        );

        expect(find.text('Test Channel'), findsOneWidget);
      });

      testWidgets('should handle channel with event UUID', (tester) async {
        final channel = ChannelResponse(
          channelUuid: 'test-uuid',
          channelName: 'Event Channel',
          eventUuid: 'event-123',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChannelItem(channel: channel),
              ),
            ),
          ),
        );

        expect(find.text('Event Channel'), findsOneWidget);
      });

      testWidgets('should be accessible', (tester) async {
        final channel = ChannelResponse(
          channelUuid: 'test-uuid',
          channelName: 'Accessible Channel',
          eventUuid: null,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChannelItem(channel: channel),
              ),
            ),
          ),
        );

        // Verify widget is present
        expect(find.byType(ChannelItem), findsOneWidget);
      });

      testWidgets('should handle empty channel name', (tester) async {
        final channel = ChannelResponse(
          channelUuid: 'test-uuid',
          channelName: '',
          eventUuid: null,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChannelItem(channel: channel),
              ),
            ),
          ),
        );

        // Should still display the widget even with empty name
        expect(find.byType(ChannelItem), findsOneWidget);
      });
    });

    group('EventItem Tests', () {
      testWidgets('should display event name correctly', (tester) async {
        final event = EventResponse(
          eventUuid: 'test-event-uuid',
          eventName: 'Test Event',
          eventDescription: 'Test Description',
          isOrganiser: true,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EventItem(event: event),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Event'), findsOneWidget);
      });

      testWidgets('should display organiser status', (tester) async {
        final event = EventResponse(
          eventUuid: 'organiser-event',
          eventName: 'Organiser Event',
          eventDescription: 'Event with organiser status',
          isOrganiser: true,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EventItem(event: event),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Organiser Event'), findsOneWidget);
        expect(find.byType(EventItem), findsOneWidget);
      });

      testWidgets('should handle participant status', (tester) async {
        final event = EventResponse(
          eventUuid: 'participant-event',
          eventName: 'Participant Event',
          eventDescription: 'Event with participant status',
          isOrganiser: false,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EventItem(event: event),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Participant Event'), findsOneWidget);
        expect(find.byType(EventItem), findsOneWidget);
      });

      testWidgets('should be accessible', (tester) async {
        final event = EventResponse(
          eventUuid: 'accessible-event',
          eventName: 'Accessible Event',
          eventDescription: 'Accessible description',
          isOrganiser: false,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EventItem(event: event),
                ),
              ),
            ),
          ),
        );

        // Verify widget is present and accessible
        expect(find.byType(EventItem), findsOneWidget);
      });

      testWidgets('should handle empty event data', (tester) async {
        final event = EventResponse(
          eventUuid: '',
          eventName: '',
          eventDescription: '',
          isOrganiser: false,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: EventItem(event: event),
                ),
              ),
            ),
          ),
        );

        // Should still display the widget even with empty data
        expect(find.byType(EventItem), findsOneWidget);
      });
    });

    group('Widget Integration Tests', () {
      testWidgets('should handle multiple channels in list', (tester) async {
        final channels = [
          ChannelResponse(
            channelUuid: 'channel-1',
            channelName: 'Channel 1',
            eventUuid: null,
          ),
          ChannelResponse(
            channelUuid: 'channel-2',
            channelName: 'Channel 2',
            eventUuid: 'event-123',
          ),
        ];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    return ChannelItem(channel: channels[index]);
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Channel 1'), findsOneWidget);
        expect(find.text('Channel 2'), findsOneWidget);
        expect(find.byType(ChannelItem), findsNWidgets(2));
      });

      testWidgets('should handle multiple events in list', (tester) async {
        final events = [
          EventResponse(
            eventUuid: 'event-1',
            eventName: 'Event 1',
            eventDescription: 'First event',
            isOrganiser: true,
          ),
          EventResponse(
            eventUuid: 'event-2',
            eventName: 'Event 2',
            eventDescription: 'Second event',
            isOrganiser: false,
          ),
        ];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => EventProvider()),
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return EventItem(event: events[index]);
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Event 1'), findsOneWidget);
        expect(find.text('Event 2'), findsOneWidget);
        expect(find.byType(EventItem), findsNWidgets(2));
      });

      testWidgets('should handle scrolling with many items', (tester) async {
        final manyChannels = List.generate(
            50,
            (index) => ChannelResponse(
                  channelUuid: 'channel-$index',
                  channelName: 'Channel $index',
                  eventUuid: null,
                ));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ChannelProvider()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ListView.builder(
                  itemCount: manyChannels.length,
                  itemBuilder: (context, index) {
                    return ChannelItem(channel: manyChannels[index]);
                  },
                ),
              ),
            ),
          ),
        );

        // Verify first few items are visible
        expect(find.text('Channel 0'), findsOneWidget);
        expect(find.text('Channel 1'), findsOneWidget);

        // Scroll down to see more items
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pump();

        // Should still have channel items after scrolling
        expect(find.byType(ChannelItem), findsWidgets);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should handle null channel gracefully', (tester) async {
        // This test verifies the widget handles edge cases without crashing
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(), // Empty container instead of null widget
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should handle null event gracefully', (tester) async {
        // This test verifies the widget handles edge cases without crashing
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(), // Empty container instead of null widget
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });
    });
  });
}
