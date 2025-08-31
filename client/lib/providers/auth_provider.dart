import 'package:flutter/material.dart';
import '../models/auth_model.dart';
import '../services/api_service.dart';
import 'settings_provider.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService? _apiService;
  final SettingsProvider? _settingsProvider;

  bool _isLoading = false;
  String? _error;
  JWTClaims? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  JWTClaims? get user => _user;
  bool get isLoggedIn => _apiService?.isLoggedIn ?? false;
  SettingsProvider? get settingsProvider => _settingsProvider;

  AuthProvider({SettingsProvider? settingsProvider, ApiService? apiService})
      : _settingsProvider = settingsProvider,
        _apiService = apiService {
    _apiService?.onAuthenticationFailed = _handleAuthenticationFailure;
    _initialize();
  }

  void _handleAuthenticationFailure() {
    debugPrint('[AuthProvider] Authentication failed - token revoked/invalid');
    // Clear user state immediately
    _user = null;
    _clearError();
    _setLoading(false); // Ensure loading state is cleared

    // Force clear any cached tokens to prevent retry loops
    _apiService?.clearAuthenticationData();

    // Force notify listeners to update UI state immediately
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return; // Prevent duplicate disposal

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
    if (_apiService == null) return;
    _setLoading(true);
    try {
      await _apiService.initializeToken();
      _user = _apiService.decodeToken();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String username, String email, String password) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      await _apiService.register(username, email, password);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    if (_apiService == null) {
      _setError('API service not available');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      await _apiService.login(email, password);
      _user = _apiService.decodeToken();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    if (_apiService == null) return;
    _setLoading(true);
    try {
      await _apiService.logout();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    if (_apiService == null) return;
    try {
      await _apiService.refreshToken();
      _user = _apiService.decodeToken();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
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
