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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event Name
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.title,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Event Name',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event!.eventName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Event Description
        if (event!.eventDescription.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event!.eventDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Event Role
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      event!.isOrganiser
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Role',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: event!.isOrganiser
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: event!.isOrganiser ? Colors.amber : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    event!.isOrganiser ? 'Organiser' : 'Participant',
                    style: TextStyle(
                      color: event!.isOrganiser
                          ? Colors.amber[800]
                          : Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Event Channels
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Event Channels',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1.0,
                        child: child,
                      ),
                    );
                  },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : ListView.builder(
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            return ChannelItem(channel: channels[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
