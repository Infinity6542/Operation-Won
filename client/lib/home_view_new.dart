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
  final MenuController _menuController = MenuController();

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

    return Consumer3<AuthProvider, EventProvider, ChannelProvider>(
      builder: (context, authProvider, eventProvider, channelProvider, child) {
        final user = authProvider.user;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildAppBar(theme, user?.username),

                // Communication Status Bar
                _buildCommsStatusBar(theme),

                // Tab Bar
                _buildTabBar(theme),

                // Content
                Expanded(
                  child: CustomRefreshIndicator(
                    onRefresh: _loadData,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEventsTab(context, eventProvider),
                        _buildChannelsTab(context, channelProvider),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(theme),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildAppBar(ThemeData theme, String? username) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
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
            onPressed: _showSettingsMenu,
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

  Widget _buildCommsStatusBar(ThemeData theme) {
    return Consumer<CommsState>(
      builder: (context, commsState, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.radio,
                color: theme.colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  commsState.currentChannelId ?? 'No channel selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(LucideIcons.plus),
              label: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // PTT Button
          Consumer<CommsState>(
            builder: (context, commsState, child) {
              if (commsState.currentChannelId == null) {
                return const SizedBox.shrink();
              }
              return Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: PTTButton(
                    size: 56,
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
              );
            },
          ),
          Consumer<CommsState>(
            builder: (context, commsState, child) {
              return SizedBox(
                width: commsState.currentChannelId != null ? 12 : 0,
              );
            },
          ),
          // Material 3 Create Menu
          MenuAnchor(
            controller: _menuController,
            alignmentOffset: const Offset(-40, -10),
            style: MenuStyle(
              backgroundColor:
                  WidgetStateProperty.all(theme.colorScheme.surfaceContainer),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: Icon(
                  LucideIcons.calendar,
                  color: theme.colorScheme.primary,
                ),
                child: const Text('Create Event'),
                onPressed: () {
                  _menuController.close();
                  _showCreateEventDialog();
                },
              ),
              MenuItemButton(
                leadingIcon: Icon(
                  LucideIcons.messageSquare,
                  color: theme.colorScheme.primary,
                ),
                child: const Text('Create Channel'),
                onPressed: () {
                  _menuController.close();
                  _showCreateChannelDialog();
                },
              ),
            ],
            child: FloatingActionButton(
              onPressed: () {
                _menuController.isOpen
                    ? _menuController.close()
                    : _menuController.open();
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(LucideIcons.plus),
            ),
          ),
        ],
      ),
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
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
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
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.bell,
                      title: 'Notifications',
                      subtitle: 'Manage your notification preferences',
                      onTap: _showNotificationsSettings,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.shield,
                      title: 'Privacy & Security',
                      subtitle: 'Control your privacy settings',
                      onTap: _showPrivacySettings,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.settings,
                      title: 'App Settings',
                      subtitle: 'Theme, language, and more',
                      onTap: _navigateToSettingsPage,
                    ),
                    _buildSettingsItem(
                      icon: LucideIcons.info,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: _showHelpAndSupport,
                    ),
                    const Divider(),
                    _buildSettingsItem(
                      icon: LucideIcons.logOut,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      onTap: () async {
                        Navigator.pop(context);
                        await authProvider.logout();
                      },
                      isDestructive: true,
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
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
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
      onTap: onTap,
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
      const SnackBar(
        content: Text('Notification settings coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPrivacySettings() {
    Navigator.pop(context); // Close the bottom sheet first
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy settings coming soon'),
        duration: Duration(seconds: 2),
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
            Text('Version: 1.0.0'),
            SizedBox(height: 16),
            Text('For support, please contact:'),
            SizedBox(height: 4),
            Text('support@operationwon.com'),
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
    final commsState = Provider.of<CommsState>(context, listen: false);
    commsState.joinChannel(channelUuid);

    // No snackbar notification needed for channel joining
  }
}
