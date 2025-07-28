import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/auth_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  JWTClaims? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  JWTClaims? get user => _user;
  bool get isLoggedIn => _apiService.isLoggedIn;

  AuthProvider() {
    _initialize();
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
      // For demo purposes, use username as email format
      String loginEmail =
          username.contains('@') ? username : '$username@demo.com';
      await _apiService.login(loginEmail, password);
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
