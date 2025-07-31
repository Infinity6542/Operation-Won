import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/event_model.dart';
import 'providers/channel_provider.dart';
import 'channel_item.dart';

class EventItem extends StatelessWidget {
  final EventResponse event;
  final VoidCallback? onTap;

  const EventItem({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ChannelProvider>(
      builder: (context, channelProvider, child) {
        final eventChannels =
            channelProvider.getChannelsForEvent(event.eventUuid);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with event info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.isOrganiser
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.isOrganiser ? 'ORGANISER' : 'MEMBER',
                          style: TextStyle(
                            color: event.isOrganiser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${eventChannels.length} channels',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Event name
                  Text(
                    event.eventName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Event description
                  if (event.eventDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.eventDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Channels preview
                  if (eventChannels.isNotEmpty) ...[
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: List.generate(
                        eventChannels.length > 3 ? 3 : eventChannels.length,
                        (index) {
                          if (index == 2 && eventChannels.length > 3) {
                            return Chip(
                              label: Text('+${eventChannels.length - 2} more'),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            );
                          }
                          return ChannelItem(
                            channel: eventChannels[index],
                            isCompact: true,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
