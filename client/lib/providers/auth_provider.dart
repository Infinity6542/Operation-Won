import 'package:flutter/material.dart';
import '../models/auth_model.dart';
import '../services/api_service.dart';
import 'settings_provider.dart';

class AuthProvider extends ChangeNotifier {
  late final ApiService _apiService;
  final SettingsProvider? _settingsProvider;

  bool _isLoading = false;
  String? _error;
  JWTClaims? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  JWTClaims? get user => _user;
  bool get isLoggedIn => _apiService.isLoggedIn;

  AuthProvider({SettingsProvider? settingsProvider})
      : _settingsProvider = settingsProvider {
    _initializeApiService();
    _initialize();
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

  Future<void> _initialize() async {
    _setLoading(true);
    try {
      await _apiService.initializeToken();
      _user = _apiService.decodeToken();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.register(username, email, password);

      // Automatically log in the user after successful registration
      String loginIdentifier = username.contains('@') ? username : email;
      await _apiService.login(loginIdentifier, password);
      _user = _apiService.decodeToken();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Send the username as-is to the server, let server handle email vs username lookup
      await _apiService.login(username, password);
      _user = _apiService.decodeToken();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiService.logout();
      _user = null;
      _clearError();
    } finally {
      _setLoading(false);
    }
    // notifyListeners() is already called in _setLoading(false)
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
