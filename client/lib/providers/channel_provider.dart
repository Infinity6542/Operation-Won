import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/channel_model.dart';
import 'settings_provider.dart';

class ChannelProvider extends ChangeNotifier {
  late final ApiService _apiService;
  final SettingsProvider? _settingsProvider;

  List<ChannelResponse> _channels = [];
  bool _isLoading = false;
  String? _error;

  List<ChannelResponse> get channels => _channels;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChannelProvider({SettingsProvider? settingsProvider})
      : _settingsProvider = settingsProvider {
    _initializeApiService();
  }

  void _initializeApiService() {
    if (_settingsProvider != null) {
      _apiService = ApiService(baseUrl: _settingsProvider.apiEndpoint);
      // Listen to settings changes to update API endpoint
      _settingsProvider.addListener(_onSettingsChanged);
    } else {
      _apiService = ApiService();
    }
  }

  void _onSettingsChanged() {
    if (_settingsProvider != null) {
      _apiService.updateBaseUrl(_settingsProvider.apiEndpoint);
    }
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> loadChannels() async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[ChannelProvider] Loading channels...');
      _channels = await _apiService.getChannels();
      debugPrint('[ChannelProvider] Loaded ${_channels.length} channels');
      _setLoading(false);
    } catch (e) {
      debugPrint('[ChannelProvider] Error loading channels: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createChannel(String channelName, {String? eventUuid}) async {
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

  List<ChannelResponse> getChannelsForEvent(String? eventUuid) {
    if (eventUuid == null) {
      return _channels.where((channel) => channel.eventUuid == null).toList();
    }
    return _channels
        .where((channel) => channel.eventUuid == eventUuid)
        .toList();
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
