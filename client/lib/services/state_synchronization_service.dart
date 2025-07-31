import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/auth_provider.dart';
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
      // Request permissions first
      await _requestPermissions(context);

      // Add a small delay to ensure authentication state is fully propagated
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify authentication before proceeding
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isLoggedIn) {
        debugPrint(
            '[StateSyncService] User not logged in, skipping data refresh');
        return;
      }

      // Get providers
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);

      // Reload all data with retry mechanism - load events first, then channels
      // This ensures proper timing for event-channel relationships
      await _loadDataWithRetry([
        () async {
          // Double-check auth before loading events
          if (!authProvider.isLoggedIn) {
            throw Exception('Authentication lost before loading events');
          }
          await eventProvider.loadEvents();
          // Small delay to ensure events are processed before channels
          await Future.delayed(const Duration(milliseconds: 100));
        },
        () async {
          // Triple-check auth before loading channels (they seem more sensitive)
          if (!authProvider.isLoggedIn) {
            throw Exception('Authentication lost before loading channels');
          }
          await channelProvider.loadChannels();
        },
      ]);

      debugPrint('[StateSyncService] Sign in data refresh completed');
    } catch (e) {
      debugPrint('[StateSyncService] Error during sign in refresh: $e');
    }
  }

  /// Load data with retry mechanism for better reliability
  static Future<void> _loadDataWithRetry(
      List<Future<void> Function()> loaders) async {
    const maxRetries = 3; // Increased retries for auth issues
    const retryDelay = Duration(milliseconds: 800); // Longer delay for auth

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Execute loaders sequentially to avoid auth conflicts
        for (final loader in loaders) {
          await loader();
          // Small delay between each loader
          await Future.delayed(const Duration(milliseconds: 100));
        }
        debugPrint(
            '[StateSyncService] Data loaded successfully on attempt ${attempt + 1}');
        return;
      } catch (e) {
        debugPrint(
            '[StateSyncService] Data load attempt ${attempt + 1} failed: $e');

        // If it's an auth error and not the last attempt, wait longer
        if ((e.toString().contains('401') ||
                e.toString().contains('authorization')) &&
            attempt < maxRetries - 1) {
          debugPrint(
              '[StateSyncService] Authentication error detected, waiting longer before retry...');
          await Future.delayed(const Duration(milliseconds: 1500));
        } else if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        } else {
          debugPrint(
              '[StateSyncService] All retry attempts failed, last error: $e');
          rethrow;
        }
      }
    }
  }

  /// Request necessary permissions for the app
  static Future<void> _requestPermissions(BuildContext context) async {
    debugPrint('[StateSyncService] Requesting permissions...');

    try {
      final commsState = CommsState.of(context, listen: false);

      // Request microphone permission for audio communication
      final hasPermission = await commsState.checkMicrophonePermission();

      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission is required for voice communication'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('[StateSyncService] Microphone permission granted');
      }
    } catch (e) {
      debugPrint('[StateSyncService] Error requesting permissions: $e');
    }
  }

  /// Force refresh all data
  static Future<void> forceRefreshAll(BuildContext context) async {
    debugPrint('[StateSyncService] Force refreshing all data...');

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);

      // Load data with retry mechanism - events first, then channels
      await _loadDataWithRetry([
        () async {
          await eventProvider.loadEvents();
          // Small delay to ensure events are processed before channels
          await Future.delayed(const Duration(milliseconds: 50));
        },
        () => channelProvider.loadChannels(),
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
