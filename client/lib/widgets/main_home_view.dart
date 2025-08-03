import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../event_item.dart';
import '../channel_item.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../providers/channel_provider.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/create_channel_dialog.dart';
import '../widgets/event_details_dialog.dart';
import '../utils/performance_utils.dart';

class OptimizedHomeView extends StatefulWidget {
  const OptimizedHomeView({super.key});

  @override
  State<OptimizedHomeView> createState() => _OptimizedHomeViewState();
}

class _OptimizedHomeViewState extends State<OptimizedHomeView>
    with AutomaticKeepAliveClientMixin, PerformanceOptimizationMixin {
  @override
  bool get wantKeepAlive => true;

  bool _hasTriggeredInitialLoad = false;

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
    super.build(context);

    return Selector3<AuthProvider, EventProvider, ChannelProvider,
        _HomeViewState>(
      selector: (context, authProvider, eventProvider, channelProvider) {
        // Load data when user becomes authenticated for the first time
        if (authProvider.user != null && !_hasTriggeredInitialLoad) {
          _hasTriggeredInitialLoad = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData();
          });
        }

        return _HomeViewState(
          user: authProvider.user,
          events: eventProvider.events,
          isLoading: eventProvider.isLoading || channelProvider.isLoading,
          standaloneChannels: channelProvider.getChannelsForEvent(null),
        );
      },
      builder: (context, homeState, child) {
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
                  // User welcome section - optimized with const
                  const _WelcomeSection(),
                  const SizedBox(height: 24),

                  // Events section - optimized with memoization
                  MemoizedWidget(
                    dependencies: [homeState.events.length],
                    builder: () => _buildEventsSection(homeState.events),
                  ),
                  const SizedBox(height: 24),

                  // Standalone channels section - optimized with memoization
                  MemoizedWidget(
                    dependencies: [homeState.standaloneChannels.length],
                    builder: () => _buildStandaloneChannelsSection(
                        homeState.standaloneChannels),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: const _OptimizedFloatingActionButtons(),
        );
      },
    );
  }

  Widget _buildEventsSection(List events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Events',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              onPressed: () => _showCreateEventDialog(),
              icon: const Icon(Icons.add),
              tooltip: 'Create Event',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const _EmptyEventsWidget()
        else
          OptimizedListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EventItem(
                event: events[index],
                onTap: () => _showEventDetails(events[index].eventUuid),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStandaloneChannelsSection(List channels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Channels',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              onPressed: () => _showCreateChannelDialog(),
              icon: const Icon(Icons.add),
              tooltip: 'Create Channel',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (channels.isEmpty)
          const _EmptyChannelsWidget()
        else
          OptimizedListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: channels.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChannelItem(channel: channels[index]),
            ),
          ),
      ],
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
}

// Immutable state class for better performance
class _HomeViewState {
  const _HomeViewState({
    required this.user,
    required this.events,
    required this.isLoading,
    required this.standaloneChannels,
  });

  final dynamic user;
  final List events;
  final bool isLoading;
  final List standaloneChannels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HomeViewState &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          _listsEqual(events, other.events) &&
          isLoading == other.isLoading &&
          _listsEqual(standaloneChannels, other.standaloneChannels);

  // Helper method to compare lists by their content hashes
  bool _listsEqual(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      // Compare by UUID for events/channels, which should be unique
      final aId = a[i]?.eventUuid ?? a[i]?.channelUuid ?? a[i].hashCode;
      final bId = b[i]?.eventUuid ?? b[i]?.channelUuid ?? b[i].hashCode;
      if (aId != bId) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      user.hashCode ^
      _getListHashCode(events) ^
      isLoading.hashCode ^
      _getListHashCode(standaloneChannels);

  // Helper method to create a hash from list contents
  int _getListHashCode(List list) {
    int hash = list.length.hashCode;
    for (final item in list) {
      final id = item?.eventUuid ?? item?.channelUuid ?? item.hashCode;
      hash ^= id.hashCode;
    }
    return hash;
  }
}

// Optimized const welcome section
class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OptimizedConsumer<AuthProvider, String?>(
      selector: (context, authProvider) => authProvider.user?.username,
      builder: (context, username, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.3),
                theme.colorScheme.surface.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      username ?? 'User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Optimized empty state widgets
class _EmptyEventsWidget extends StatelessWidget {
  const _EmptyEventsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No events yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first event to get started',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyChannelsWidget extends StatelessWidget {
  const _EmptyChannelsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No channels yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first channel to start communicating',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Optimized floating action buttons
class _OptimizedFloatingActionButtons extends StatefulWidget {
  const _OptimizedFloatingActionButtons();

  @override
  State<_OptimizedFloatingActionButtons> createState() =>
      _OptimizedFloatingActionButtonsState();
}

class _OptimizedFloatingActionButtonsState
    extends State<_OptimizedFloatingActionButtons>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _topButtonAnimation;
  late Animation<double> _bottomButtonAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Bottom button (Create Channel) animates in first, out last
    _bottomButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeInBack),
    ));

    // Top button (Create Event) animates in second, out first
    _topButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      reverseCurve: const Interval(0.0, 0.5, curve: Curves.easeInBack),
    ));

    // Start the animation when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top button (Create Event) - animates in second, out first
        AnimatedBuilder(
          animation: _topButtonAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _topButtonAnimation.value,
              child: Opacity(
                opacity: _topButtonAnimation.value,
                child: FloatingActionButton.small(
                  onPressed: () => _showCreateEventDialog(context),
                  heroTag: "createEvent",
                  tooltip: 'Create Event',
                  child: const Icon(Icons.event_available),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Bottom button (Create Channel) - animates in first, out last
        AnimatedBuilder(
          animation: _bottomButtonAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bottomButtonAnimation.value,
              child: Opacity(
                opacity: _bottomButtonAnimation.value,
                child: FloatingActionButton.small(
                  onPressed: () => _showCreateChannelDialog(context),
                  heroTag: "createChannel",
                  tooltip: 'Create Channel',
                  child: const Icon(Icons.chat),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showCreateEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateEventDialog(),
    );
  }

  void _showCreateChannelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateChannelDialog(),
    );
  }
}
