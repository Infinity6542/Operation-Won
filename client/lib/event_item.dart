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
    return Consumer<ChannelProvider>(
      builder: (context, channelProvider, child) {
        final eventChannels =
            channelProvider.getChannelsForEvent(event.eventUuid);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with event info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.isOrganiser
                              ? const Color(0xFF059669)
                              : const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.isOrganiser ? 'ORGANISER' : 'MEMBER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${eventChannels.length} channels',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Event name
                  Text(
                    event.eventName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Event description
                  if (event.eventDescription.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.eventDescription,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Channels preview
                  if (eventChannels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Channels:',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            eventChannels.length > 3 ? 3 : eventChannels.length,
                        itemBuilder: (context, index) {
                          if (index == 2 && eventChannels.length > 3) {
                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF6B7280)),
                              ),
                              child: Center(
                                child: Text(
                                  '+${eventChannels.length - 2}',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: ChannelItem(
                              channel: eventChannels[index],
                              isCompact: true,
                            ),
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
