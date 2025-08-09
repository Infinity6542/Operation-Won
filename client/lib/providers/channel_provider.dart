import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/channel_model.dart';
import 'settings_provider.dart';

class ChannelProvider extends ChangeNotifier {
  final ApiService? _apiService;

  List<ChannelResponse> _channels = [];
  bool _isLoading = false;
  String? _error;

  List<ChannelResponse> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChannelProvider({SettingsProvider? settingsProvider, ApiService? apiService})
      : _apiService = apiService;

  Future<void> loadChannels() async {
    if (_apiService == null) {
      _setError('API service not available');
      return;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[ChannelProvider] Loading channels...');
      _channels = await _apiService.getChannels();
      debugPrint('[ChannelProvider] Loaded ${_channels.length} channels');

      // Debug: Print channel details for troubleshooting
      for (final channel in _channels) {
        debugPrint(
            '[ChannelProvider] Channel: ${channel.channelName} (UUID: ${channel.channelUuid}, EventUUID: ${channel.eventUuid})');
      }

      _setLoading(false);
    } catch (e) {
      debugPrint('[ChannelProvider] Error loading channels: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createChannel(String channelName, {String? eventUuid}) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[ChannelProvider] Creating channel: $channelName');
      await _apiService.createChannel(channelName, eventUuid: eventUuid);
      debugPrint(
          '[ChannelProvider] Channel created successfully, refreshing list...');
      await loadChannels(); // Refresh the list
      debugPrint(
          '[ChannelProvider] Channel list refreshed, notifying listeners');
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[ChannelProvider] Error creating channel: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> joinChannel(String inviteCode) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint(
          '[ChannelProvider] Joining channel with invite code: $inviteCode');
      final channelName = await _apiService.joinChannel(inviteCode);
      debugPrint(
          '[ChannelProvider] Joined channel: $channelName, refreshing list...');
      await loadChannels(); // Refresh the list to show the newly joined channel
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[ChannelProvider] Error joining channel: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteChannel(String channelUuid) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[ChannelProvider] Deleting channel: $channelUuid');
      await _apiService.deleteChannel(channelUuid);
      debugPrint(
          '[ChannelProvider] Channel deleted successfully, refreshing list...');
      await loadChannels(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[ChannelProvider] Error deleting channel: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateChannel(String channelUuid, String newChannelName) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint(
          '[ChannelProvider] Updating channel $channelUuid to $newChannelName');
      await _apiService.updateChannel(channelUuid, newChannelName);
      debugPrint(
          '[ChannelProvider] Channel updated successfully, refreshing list...');
      await loadChannels(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[ChannelProvider] Error updating channel: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  List<ChannelResponse> getChannelsForEvent(String? eventUuid) {
    debugPrint('[ChannelProvider] Getting channels for event: $eventUuid');

    List<ChannelResponse> result;
    if (eventUuid == null) {
      result = _channels.where((channel) => channel.eventUuid == null).toList();
      debugPrint(
          '[ChannelProvider] Found ${result.length} channels with no event UUID');
    } else {
      result =
          _channels.where((channel) => channel.eventUuid == eventUuid).toList();
      debugPrint(
          '[ChannelProvider] Found ${result.length} channels for event $eventUuid');
    }

    // Debug: Print matching channels
    for (final channel in result) {
      debugPrint(
          '[ChannelProvider] - ${channel.channelName} (${channel.channelUuid})');
    }

    return result;
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearError() => _clearError();

  /// Clear all cached channels data
  void clearData() {
    _channels.clear();
    _clearError();
    notifyListeners();
    debugPrint('[ChannelProvider] Data cleared');
  }
}
