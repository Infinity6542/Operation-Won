import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../providers/channel_provider.dart';
import '../channel_item.dart';

class EventDetailsDialog extends StatefulWidget {
  final String eventUuid;

  const EventDetailsDialog({
    super.key,
    required this.eventUuid,
  });

  @override
  State<EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<EventDetailsDialog> {
  EventResponse? event;
  List channels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  void _loadEventDetails() {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final channelProvider =
        Provider.of<ChannelProvider>(context, listen: false);

    // Find the event in the loaded events
    final events = eventProvider.events;
    try {
      final foundEvent = events.firstWhere(
        (e) => e.eventUuid == widget.eventUuid,
      );
      event = foundEvent;
      // Get channels for this event
      channels = channelProvider.getChannelsForEvent(widget.eventUuid);
    } catch (e) {
      // Event not found
      event = null;
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.all(isSmallScreen ? 16 : 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.85,
          maxWidth: isSmallScreen ? screenSize.width - 32 : 600,
          minWidth: isSmallScreen ? screenSize.width - 32 : 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Event Details',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : event == null
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Event not found'),
                            ),
                          )
                        : _buildEventDetails(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event Name
        _buildInfoCard(
          theme,
          icon: Icons.title,
          title: 'Event Name',
          content: Text(
            event!.eventName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Event Description
        if (event!.eventDescription.isNotEmpty) ...[
          _buildInfoCard(
            theme,
            icon: Icons.description,
            title: 'Description',
            content: Text(
              event!.eventDescription,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Event Role
        _buildInfoCard(
          theme,
          icon: event!.isOrganiser ? Icons.admin_panel_settings : Icons.person,
          title: 'Your Role',
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: event!.isOrganiser
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: event!.isOrganiser
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.tertiary,
                width: 1,
              ),
            ),
            child: Text(
              event!.isOrganiser ? 'Organiser' : 'Participant',
              style: theme.textTheme.labelLarge?.copyWith(
                color: event!.isOrganiser
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Event Channels
        _buildInfoCard(
          theme,
          icon: Icons.chat,
          title: 'Event Channels',
          content: Column(
            children: [
              if (channels.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('No channels found for this event.'),
                )
              else
                ...channels.map(
                  (channel) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ChannelItem(channel: channel),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme,
      {required IconData icon,
      required String title,
      required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.cardTheme.shape is RoundedRectangleBorder
                ? (theme.cardTheme.shape as RoundedRectangleBorder).side.color
                : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}
