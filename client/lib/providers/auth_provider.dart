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
  SettingsProvider? get settingsProvider => _settingsProvider;

  AuthProvider({SettingsProvider? settingsProvider})
      : _settingsProvider = settingsProvider {
    _initializeApiService();
    _initialize();
  }

  void _initializeApiService() {
    if (_settingsProvider != null) {
      debugPrint(
          'AuthProvider: Using settings provider endpoint: ${_settingsProvider.apiEndpoint}');
      _apiService = ApiService(
        baseUrl: _settingsProvider.apiEndpoint,
        onAuthenticationFailed: _handleAuthenticationFailure,
      );
      // Listen to settings changes to update API endpoint
      _settingsProvider.addListener(_onSettingsChanged);
    } else {
      debugPrint(
          'AuthProvider: No settings provider, using default API service');
      _apiService = ApiService(
        onAuthenticationFailed: _handleAuthenticationFailure,
      );
    }
  }

  void _onSettingsChanged() {
    if (_settingsProvider != null) {
      _apiService.updateBaseUrl(_settingsProvider.apiEndpoint);
    }
  }

  void _handleAuthenticationFailure() {
    debugPrint('[AuthProvider] Authentication failed - token revoked/invalid');
    // Clear user state immediately
    _user = null;
    _clearError();
    _setLoading(false); // Ensure loading state is cleared
    
    // Force clear any cached tokens to prevent retry loops
    _apiService.clearAuthenticationData();
    
    // Force notify listeners to update UI state immediately
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return; // Prevent duplicate disposal

    _settingsProvider?.removeListener(_onSettingsChanged);
    _isDisposed = true;

    try {
      super.dispose();
    } catch (e) {
      // Ignore disposal errors during hot reload
      debugPrint(
          '[AuthProvider] Ignoring disposal error during hot reload: $e');
    }
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
      debugPrint('[AuthProvider] User logged out successfully');
      
      // Ensure auth state is immediately updated to prevent any pending operations
      if (!_isDisposed) {
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
    // notifyListeners() is already called in _setLoading(false)
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _setError(String error) {
    if (_error != error) {
      _error = error;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void clearError() => _clearError();
}
