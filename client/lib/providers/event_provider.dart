import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/event_model.dart';

class EventProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<EventResponse> _events = [];
  bool _isLoading = false;
  String? _error;

  List<EventResponse> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents() async {
    _setLoading(true);
    _clearError();

    try {
      _events = await _apiService.getEvents();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createEvent(String eventName, {String? eventDescription}) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.createEvent(eventName,
          eventDescription: eventDescription);
      await loadEvents(); // Refresh the list
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() => _clearError();
}
