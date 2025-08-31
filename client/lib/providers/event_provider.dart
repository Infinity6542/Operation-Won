import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/event_model.dart';
import 'settings_provider.dart';

class EventProvider extends ChangeNotifier {
  final ApiService? _apiService;

  List<EventResponse> _events = [];
  bool _isLoading = false;
  String? _error;

  List<EventResponse> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  EventProvider({SettingsProvider? settingsProvider, ApiService? apiService})
      : _apiService = apiService;

  Future<void> loadEvents() async {
    if (_apiService == null) {
      _setError('API service not available');
      return;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Loading events...');
      _events = await _apiService.getEvents();
      debugPrint('[EventProvider] Loaded ${_events.length} events');

      // Debug: Print event details for troubleshooting
      for (final event in _events) {
        debugPrint(
            '[EventProvider] Event: ${event.eventName} (UUID: ${event.eventUuid})');
        debugPrint('  - Invite code: ${event.inviteCode}');
        debugPrint('  - Is organiser: ${event.isOrganiser}');
      }

      _setLoading(false);
    } catch (e) {
      debugPrint('[EventProvider] Error loading events: $e');
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createEvent(String eventName, {String? eventDescription}) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
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

  Future<bool> deleteEvent(String eventUuid) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Deleting event: $eventUuid');
      await _apiService.deleteEvent(eventUuid);
      debugPrint(
          '[EventProvider] Event deleted successfully, refreshing list...');
      await loadEvents(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[EventProvider] Error deleting event: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateEvent(String eventUuid, String newEventName,
      {String? newEventDescription}) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Updating event $eventUuid to $newEventName');
      await _apiService.updateEvent(eventUuid, newEventName,
          newEventDescription: newEventDescription);
      debugPrint(
          '[EventProvider] Event updated successfully, refreshing list...');
      await loadEvents(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[EventProvider] Error updating event: $e');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> joinEvent(String inviteCode) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      debugPrint('[EventProvider] Joining event with code: $inviteCode');
      await _apiService.joinEvent(inviteCode);
      debugPrint(
          '[EventProvider] Joined event successfully, refreshing list...');
      await loadEvents(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('[EventProvider] Error joining event: $e');
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

  /// Clear all cached events data
  void clearData() {
    _events.clear();
    _clearError();
    notifyListeners();
    debugPrint('[EventProvider] Data cleared');
  }
}
