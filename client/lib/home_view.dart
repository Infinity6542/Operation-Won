import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/join_event_dialog.dart';
import 'widgets/join_channel_dialog.dart';
import 'widgets/ptt_gesture_zone.dart';
import 'widgets/refresh_indicator.dart';
import 'services/state_synchronization_service.dart';
import 'pages/settings_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  bool _isSpeedDialOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await StateSynchronizationService.forceRefreshAll(context);
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSettingsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Consumer4<AuthProvider, EventProvider, ChannelProvider, CommsState>(
      builder: (context, auth, events, channels, commsState, child) {
        final user = auth.user;
        final isInChannel = commsState.currentChannelId != null;

        const pttHeightFraction = 0.8; // 4/5 of the screen
        const contentHeightFraction = 0.2; // 1/5 of the screen
        const animationDuration = Duration(milliseconds: 400);

        final screenHeight = MediaQuery.of(context).size.height;

        // Determine animated positions and sizes
        final double contentHeight = isInChannel
            ? screenHeight * contentHeightFraction
            : screenHeight * (1 - contentHeightFraction);

        final double pttHeight = isInChannel
            ? screenHeight * pttHeightFraction
            : screenHeight * contentHeightFraction;

        final double contentTop = 0;
        final double pttTop = contentHeight;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Animated Content Area (Events/Channels)
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeInOut,
                top: contentTop,
                left: 0,
                right: 0,
                height: contentHeight,
                child: IgnorePointer(
                  ignoring: isInChannel, // Disable interaction when collapsed
                  child: AnimatedOpacity(
                    duration: animationDuration,
                    opacity: isInChannel ? 0.5 : 1.0,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                        left: MediaQuery.of(context).padding.left,
                        right: MediaQuery.of(context).padding.right,
                      ),
                      child: Column(
                        children: [
                          // Fixed header sections
                          _buildAppBar(theme, user?.username, isInChannel),
                          _buildCommsStatusBar(theme, isInChannel),
                          _buildTabBar(theme, isInChannel),

                          // Scrollable content area
                          Expanded(
                            child: CustomRefreshIndicator(
                              onRefresh: _loadData,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildEventsTab(context, events),
                                  _buildChannelsTab(context, channels),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Animated PTT Gesture Zone
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeInOut,
                top: pttTop,
                left: 0,
                right: 0,
                height: pttHeight,
                child: PTTGestureZone(
                  onPermissionDenied: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Microphone permission required'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                ),
              ),

              // Scrim overlay for Speed Dial
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  opacity: _isSpeedDialOpen ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isSpeedDialOpen,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isSpeedDialOpen = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withAlpha(128),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Action Button fixed at bottom-right corner
              Positioned(
                bottom: 16, // 16px from bottom edge
                right: 16, // 16px from right edge
                child: _buildFloatingActionButton(theme, auth),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ThemeData theme, String? username, bool isCollapsed) {
    if (isCollapsed) {
      return const SizedBox.shrink(); // Hide app bar when collapsed
    }
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(
              LucideIcons.user,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  username ?? 'User',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Light haptic feedback for settings menu access
              HapticFeedback.lightImpact();
              _showSettingsMenu();
            },
            icon: const Icon(LucideIcons.settings),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainer,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommsStatusBar(ThemeData theme, bool isCollapsed) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(isCollapsed ? 8 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.radio,
                color: theme.colorScheme.primary,
                size: isCollapsed ? 12 : 16,
              ),
              SizedBox(width: isCollapsed ? 4 : 8),
              Expanded(
                child: Text(
                  commsState.currentChannelId ?? 'No channel selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: isCollapsed ? 12 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildConnectionDot(theme, commsState.isConnected),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionDot(ThemeData theme, bool isConnected) {
    final color =
        isConnected ? theme.colorScheme.secondary : theme.colorScheme.error;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, bool isCollapsed) {
    if (isCollapsed) {
      return const SizedBox.shrink(); // Hide tab bar when collapsed
    }
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          // Selection haptic feedback for tab changes
          HapticFeedback.selectionClick();
        },
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.calendar, size: 16),
                SizedBox(width: 8),
                Text('Events'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.messageSquare, size: 16),
                SizedBox(width: 8),
                Text('Channels'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab(BuildContext context, EventProvider eventProvider) {
    if (eventProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eventProvider.events.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.calendar,
        title: 'No Events Yet',
        subtitle:
            'Create your first event to get started with team coordination',
        actionText: 'Create Event',
        onAction: _showCreateEventDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eventProvider.events.length,
      itemBuilder: (context, index) {
        final event = eventProvider.events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EventItem(
            event: event,
            onTap: () => _showEventDetails(event.eventUuid),
          ),
        );
      },
    );
  }

  Widget _buildChannelsTab(
      BuildContext context, ChannelProvider channelProvider) {
    final standaloneChannels = channelProvider.getChannelsForEvent(null);

    if (channelProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (standaloneChannels.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.messageSquare,
        title: 'No Channels Yet',
        subtitle: 'Create communication channels for your team',
        actionText: 'Create Channel',
        onAction: _showCreateChannelDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: standaloneChannels.length,
      itemBuilder: (context, index) {
        final channel = standaloneChannels[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChannelItem(
            channel: channel,
            onTap: () => _openChannel(channel.channelUuid),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Use the + button to $actionText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(
      ThemeData theme, AuthProvider authProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial options - show when menu is open
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Join Event button (appears first when opening)
            _buildAnimatedSpeedDialItem(
              icon: LucideIcons.userPlus,
              label: 'Join Event',
              onTap: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                _showJoinEventDialog();
              },
              theme: theme,
              delay: _isSpeedDialOpen ? 0 : 60,
              duration: 230,
            ),
            const SizedBox(height: 8),
            // Join Channel button (appears second when opening)
            _buildAnimatedSpeedDialItem(
              icon: LucideIcons.radio,
              label: 'Join Channel',
              onTap: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                // Check authentication before showing dialog
                if (authProvider.isLoggedIn) {
                  _showJoinChannelDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please log in to join channels.'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              theme: theme,
              delay: _isSpeedDialOpen ? 8 : 52,
              duration: 240,
            ),
            const SizedBox(height: 8),
            // Event button (appears third when opening)
            _buildAnimatedSpeedDialItem(
              icon: LucideIcons.calendar,
              label: 'Create Event',
              onTap: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                _showCreateEventDialog();
              },
              theme: theme,
              delay: _isSpeedDialOpen ? 15 : 45,
              duration: 250,
            ),
            const SizedBox(height: 8),
            // Channel button (appears fourth when opening)
            _buildAnimatedSpeedDialItem(
              icon: LucideIcons.messageSquare,
              label: 'Create Channel',
              onTap: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                // Check authentication before showing dialog
                if (authProvider.isLoggedIn) {
                  _showCreateChannelDialog();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please log in to create channels.'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              theme: theme,
              delay: _isSpeedDialOpen ? 23 : 37,
              duration: 270,
            ),
            const SizedBox(height: 20), // More space before main FAB
          ],
        ),
        // Main FAB
        TweenAnimationBuilder<double>(
          duration:
              const Duration(milliseconds: 200), // Faster main FAB animation
          curve: Curves.easeInOut,
          tween: Tween(begin: 1.0, end: _isSpeedDialOpen ? 1.1 : 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: FloatingActionButton(
                onPressed: () {
                  // Light haptic feedback for FAB interaction
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSpeedDialOpen = !_isSpeedDialOpen;
                  });
                },
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: _isSpeedDialOpen ? 8 : 6,
                child: AnimatedRotation(
                  duration:
                      const Duration(milliseconds: 200), // Faster rotation
                  curve: Curves.easeInOut,
                  turns: _isSpeedDialOpen ? 0.125 : 0, // 45 degree rotation
                  child: const Icon(LucideIcons.plus),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedSpeedDialItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    required int delay,
    required int duration,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: duration),
      curve: Curves.easeInOut,
      tween: Tween(begin: 0.0, end: _isSpeedDialOpen ? 1.0 : 0.0),
      builder: (context, value, child) {
        // Apply delay by modifying the animation curve
        double delayedValue = value;
        if (delay > 0) {
          final delayFactor = delay / duration.toDouble();
          if (_isSpeedDialOpen) {
            // When opening: delay the start
            delayedValue = value > delayFactor
                ? (value - delayFactor) / (1 - delayFactor)
                : 0.0;
          } else {
            // When closing: delay the start by starting earlier
            delayedValue =
                value < (1 - delayFactor) ? value / (1 - delayFactor) : 1.0;
          }
        }

        return Transform.translate(
          offset: Offset(0, 20 * (1 - delayedValue)),
          child: Transform.scale(
            scale: 0.8 + (0.2 * delayedValue),
            child: Opacity(
              opacity: delayedValue,
              child: IgnorePointer(
                ignoring: !_isSpeedDialOpen ||
                    delayedValue <=
                        0.1, // Ignore when closed OR when mostly invisible
                child: _buildSpeedDialOption(
                  icon: icon,
                  label: label,
                  onTap: onTap,
                  theme: theme,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label with enhanced styling
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius:
                      BorderRadius.circular(24), // More rounded to match FAB
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16, // Scaled up text
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        // Square FAB matching the main FAB size
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: SizedBox(
                  width: 56, // Same size as regular FAB
                  height: 56,
                  child: FloatingActionButton(
                    onPressed: () {
                      // Medium haptic feedback for speed dial action selection
                      HapticFeedback.mediumImpact();
                      onTap();
                    },
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 4,
                    heroTag: label, // Prevent hero animation conflicts
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16), // Square-ish but rounded
                    ),
                    child: Icon(icon, size: 24), // Larger icon to match scale
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsBottomSheet() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.settings,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Settings Items
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  children: [
                    _buildSettingsItem(
                      icon: LucideIcons.user,
                      title: 'Profile',
                      subtitle: authProvider.user?.username ?? 'Unknown User',
                      onTap: _showProfileDialog,
                      theme: theme,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.bell,
                      title: 'Notifications',
                      subtitle: 'Manage your notification preferences',
                      onTap: _showNotificationsSettings,
                      theme: theme,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.shield,
                      title: 'Privacy & Security',
                      subtitle: 'Control your privacy settings',
                      onTap: _showPrivacySettings,
                      theme: theme,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.settings,
                      title: 'App Settings',
                      subtitle: 'Theme, language, and more',
                      onTap: _navigateToSettingsPage,
                      theme: theme,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.info,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: _showHelpAndSupport,
                      theme: theme,
                    ),
                    const Divider(),
                    _buildSettingsItem(
                      icon: LucideIcons.logOut,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      onTap: () async {
                        // Heavy haptic feedback for destructive actions
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        await authProvider.logout();
                      },
                      isDestructive: true,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isDestructive = false,
  }) {
    final iconColor =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.primary;
    final titleColor =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () {
        // Light haptic feedback for settings menu navigation
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  void _navigateToSettingsPage() {
    Navigator.pop(context); // Close the bottom sheet first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
          ),
          body: const SettingsView(),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    Navigator.pop(context); // Close the bottom sheet first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user?.username ?? "Unknown"}'),
            const SizedBox(height: 8),
            Text('User ID: ${user?.userId ?? "Unknown"}'),
            const SizedBox(height: 8),
            Text(
                'Status: ${authProvider.isLoggedIn ? "Logged in" : "Not logged in"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSettings() {
    Navigator.pop(context); // Close the bottom sheet first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification settings coming soon'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacySettings() {
    Navigator.pop(context); // Close the bottom sheet first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Privacy settings coming soon'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelpAndSupport() {
    Navigator.pop(context); // Close the bottom sheet first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operation Won - Communication App'),
            SizedBox(height: 8),
            Text('Version: 0.0.1a'),
            SizedBox(height: 16),
            Text('No support just yet :).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateEventDialog(),
    );
  }

  void _showJoinEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const JoinEventDialog(),
    );
  }

  void _showJoinChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => const JoinChannelDialog(),
    );
  }

  void _showCreateChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateChannelDialog(),
    );
  }

  void _showEventDetails(String eventUuid) {
    // Light haptic feedback for event selection
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(eventUuid: eventUuid),
    );
  }

  void _openChannel(String channelUuid) {
    // Medium haptic feedback for channel joining (more impactful action)
    HapticFeedback.mediumImpact();
    final commsState = Provider.of<CommsState>(context, listen: false);
    commsState.joinChannel(channelUuid);

    // No snackbar notification needed for channel joining
  }
}
