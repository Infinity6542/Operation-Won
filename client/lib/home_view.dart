import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'event_item.dart';
import 'channel_item.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/channel_provider.dart';
import 'widgets/create_event_dialog.dart';
import 'widgets/create_channel_dialog.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final channelProvider =
        Provider.of<ChannelProvider>(context, listen: false);

    await Future.wait([
      eventProvider.loadEvents(),
      channelProvider.loadChannels(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Consumer3<AuthProvider, EventProvider, ChannelProvider>(
      builder: (context, authProvider, eventProvider, channelProvider, child) {
        final user = authProvider.user;
        final standaloneChannels = channelProvider.getChannelsForEvent(null);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user?.username ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Events Section
                  Row(
                    children: [
                      const Text(
                        'Events',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showCreateEventDialog(),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Create'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (eventProvider.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (eventProvider.events.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6B7280)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events yet',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first event to get started',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: eventProvider.events.length,
                        itemBuilder: (context, index) {
                          final event = eventProvider.events[index];
                          return SizedBox(
                            width: 300,
                            child: EventItem(
                              event: event,
                              onTap: () => _showEventDetails(event.eventUuid),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Standalone Channels Section
                  Row(
                    children: [
                      const Text(
                        'Standalone Channels',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showCreateChannelDialog(),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Create'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (channelProvider.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (standaloneChannels.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6B7280)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            LucideIcons.messageSquare,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No standalone channels',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create channels for direct communication',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: standaloneChannels.length,
                      itemBuilder: (context, index) {
                        final channel = standaloneChannels[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ChannelItem(
                            channel: channel,
                            onTap: () => _openChannel(channel.channelUuid),
                          ),
                        );
                      },
                    ),

                  // Error handling
                  if (eventProvider.error != null ||
                      channelProvider.error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        eventProvider.error ??
                            channelProvider.error ??
                            'Unknown error',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: "create_channel",
                onPressed: () => _showCreateChannelDialog(),
                backgroundColor: const Color(0xFF10B981),
                child:
                    const Icon(LucideIcons.messageSquare, color: Colors.white),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "create_event",
                onPressed: () => _showCreateEventDialog(),
                backgroundColor: const Color(0xFF3B82F6),
                child: const Icon(LucideIcons.calendar, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateEventDialog(),
    );
  }

  void _showCreateChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateChannelDialog(),
    );
  }

  void _showEventDetails(String eventUuid) {
    // TODO: Navigate to event details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening event: $eventUuid')),
    );
  }

  void _openChannel(String channelUuid) {
    // TODO: Navigate to channel page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening channel: $channelUuid')),
    );
  }
}
