import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/event_model.dart';
import 'settings_provider.dart';

class EventProvider extends ChangeNotifier {
  late final ApiService _apiService;
  final SettingsProvider? _settingsProvider;

  List<EventResponse> _events = [];
  bool _isLoading = false;
  String? _error;

  List<EventResponse> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EventProvider({SettingsProvider? settingsProvider, ApiService? apiService})
      : _settingsProvider = settingsProvider {
    if (apiService != null) {
      _apiService = apiService;
    } else {
      _initializeApiService();
    }
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

  Future<void> loadEvents() async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Loading events...');
      _events = await _apiService.getEvents();
      debugPrint('[EventProvider] Loaded ${_events.length} events');
      _setLoading(false);
    } catch (e) {
      debugPrint('[EventProvider] Error loading events: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createEvent(String eventName, {String? eventDescription}) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Creating event: $eventName');
      await _apiService.createEvent(eventName,
          eventDescription: eventDescription);
      debugPrint(
          '[EventProvider] Event created successfully, refreshing list...');
      await loadEvents(); // Refresh the list
      debugPrint('[EventProvider] Event list refreshed, notifying listeners');
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[EventProvider] Error creating event: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
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
}
