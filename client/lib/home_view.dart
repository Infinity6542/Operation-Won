import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'event_item.dart';
import 'channel_item.dart';
import 'comms_state.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/channel_provider.dart';
import 'widgets/create_event_dialog.dart';
import 'widgets/event_details_dialog.dart';
import 'widgets/create_channel_dialog.dart';
import 'widgets/ptt_button.dart';

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

                  // Communication Panel
                  Consumer<CommsState>(
                    builder: (context, commsState, child) {
                      return Card(
                        color: const Color(0xFF1E293B),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.radio,
                                    color: Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Communication',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildConnectionStatus(commsState),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (commsState.currentChannelId == null) ...[
                                // No channel selected
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        LucideIcons.micOff,
                                        color: Colors.grey[400],
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Select a channel to start communicating',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // Channel selected - show PTT controls
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            commsState.isEmergencyMode
                                                ? 'Emergency Channel'
                                                : 'Active Channel',
                                            style: TextStyle(
                                              color: commsState.isEmergencyMode
                                                  ? Colors.red
                                                  : Colors.grey[400],
                                              fontSize: 12,
                                              fontWeight:
                                                  commsState.isEmergencyMode
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (commsState.isEmergencyMode)
                                                Icon(
                                                  LucideIcons.triangle,
                                                  color: Colors.red,
                                                  size: 14,
                                                ),
                                              if (commsState.isEmergencyMode)
                                                const SizedBox(width: 4),
                                              Text(
                                                commsState.currentChannelId!,
                                                style: TextStyle(
                                                  color:
                                                      commsState.isEmergencyMode
                                                          ? Colors.red
                                                          : Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Emergency exit button
                                    if (commsState.isEmergencyMode) ...[
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await commsState.exitEmergencyMode();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Exited emergency mode'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                        icon:
                                            const Icon(LucideIcons.x, size: 16),
                                        label: const Text('Exit Emergency'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    PTTButton(
                                      size: 60,
                                      onPermissionDenied: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Microphone permission required for Push-to-Talk'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(eventUuid: eventUuid),
    );
  }

  void _openChannel(String channelUuid) {
    // Join the channel for communication
    final commsState = Provider.of<CommsState>(context, listen: false);
    commsState.joinChannel(channelUuid);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined channel for communication'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildConnectionStatus(CommsState commsState) {
    final isConnected = commsState.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
