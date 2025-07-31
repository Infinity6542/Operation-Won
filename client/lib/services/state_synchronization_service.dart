import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/channel_provider.dart';
import '../comms_state.dart';

/// Service to handle state synchronization across the application
/// Ensures UI updates are properly reflected when data changes
class StateSynchronizationService extends ChangeNotifier {
  static StateSynchronizationService? _instance;

  static StateSynchronizationService get instance {
    _instance ??= StateSynchronizationService._();
    return _instance!;
  }

  StateSynchronizationService._();

  /// Clear all data when user signs out
  static Future<void> handleSignOut(BuildContext context) async {
    debugPrint('[StateSyncService] Handling sign out...');

    try {
      // Get providers
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);
      final commsState = Provider.of<CommsState>(context, listen: false);

      // Clear all cached data
      eventProvider.clearData();
      channelProvider.clearData();

      // Disconnect from communications
      await commsState.disconnectFromServer();

      debugPrint('[StateSyncService] Sign out cleanup completed');
    } catch (e) {
      debugPrint('[StateSyncService] Error during sign out cleanup: $e');
    }
  }

  /// Refresh all data when user signs in
  static Future<void> handleSignIn(BuildContext context) async {
    debugPrint('[StateSyncService] Handling sign in...');

    try {
      // Get providers
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);

      // Reload all data
      await Future.wait([
        eventProvider.loadEvents(),
        channelProvider.loadChannels(),
      ]);

      debugPrint('[StateSyncService] Sign in data refresh completed');
    } catch (e) {
      debugPrint('[StateSyncService] Error during sign in refresh: $e');
    }
  }

  /// Force refresh all data
  static Future<void> forceRefreshAll(BuildContext context) async {
    debugPrint('[StateSyncService] Force refreshing all data...');

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);

      await Future.wait([
        eventProvider.loadEvents(),
        channelProvider.loadChannels(),
      ]);

      debugPrint('[StateSyncService] Force refresh completed');
    } catch (e) {
      debugPrint('[StateSyncService] Error during force refresh: $e');
    }
  }

  /// Handle event creation completion
  static Future<void> handleEventCreated(
      BuildContext context, String eventName) async {
    debugPrint('[StateSyncService] Handling event creation: $eventName');

    // Event provider already refreshes itself, but we might want to refresh channels too
    // in case the new event affects channel listings
    try {
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);
      await channelProvider.loadChannels();
    } catch (e) {
      debugPrint(
          '[StateSyncService] Error refreshing channels after event creation: $e');
    }
  }

  /// Handle channel creation completion
  static Future<void> handleChannelCreated(
      BuildContext context, String channelName) async {
    debugPrint('[StateSyncService] Handling channel creation: $channelName');

    // Channel provider already refreshes itself, this is for any additional actions
    // that might be needed in the future
  }

  /// Handle settings changes that might affect data
  static Future<void> handleSettingsChanged(
      BuildContext context, String settingKey) async {
    debugPrint('[StateSyncService] Handling settings change: $settingKey');

    // If API endpoint changed, we might need to reconnect and refresh data
    if (settingKey == 'api_endpoint' || settingKey == 'websocket_endpoint') {
      try {
        final commsState = Provider.of<CommsState>(context, listen: false);
        await commsState.disconnectFromServer();

        // Don't auto-reconnect here as user might want to test first
      } catch (e) {
        debugPrint('[StateSyncService] Error handling endpoint change: $e');
      }
    }
  }

  /// Schedule a delayed refresh (useful for network operations)
  static void scheduleRefresh(BuildContext context,
      {Duration delay = const Duration(milliseconds: 500)}) {
    Future.delayed(delay, () {
      if (context.mounted) {
        forceRefreshAll(context);
      }
    });
  }
}

/// Mixin for widgets that need state synchronization
mixin StateSynchronizationMixin<T extends StatefulWidget> on State<T> {
  /// Refresh data with loading indicator
  Future<void> refreshData() async {
    await StateSynchronizationService.forceRefreshAll(context);
  }

  /// Clear and refresh data (useful after operations that might change state)
  Future<void> clearAndRefresh() async {
    await StateSynchronizationService.forceRefreshAll(context);
  }
}
