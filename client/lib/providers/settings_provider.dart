import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsProvider extends ChangeNotifier {
  static const String _apiEndpointKey = 'api_endpoint';
  static const String _websocketEndpointKey = 'websocket_endpoint';
  static const String _themeModeKey = 'theme_mode';
  static const String _pttModeKey = 'ptt_mode';
  static const String _magicMicKey = 'magic_mic_enabled';

  // Default values
  static const String _defaultApiEndpoint = 'http://localhost:8000';
  static const String _defaultWebsocketEndpoint = 'http://localhost:8000/msg';
  static const String _defaultThemeMode = 'dark';
  static const String _defaultPttMode = 'hold';
  static const bool _defaultMagicMicEnabled = true;

  // Private fields
  String _apiEndpoint = _defaultApiEndpoint;
  String _websocketEndpoint = _defaultWebsocketEndpoint;
  String _themeMode = _defaultThemeMode;
  String _pttMode = _defaultPttMode;
  bool _magicMicEnabled = _defaultMagicMicEnabled;

  SharedPreferences? _prefs;
  bool _isLoaded = false;

  // Debounce timer to prevent excessive SharedPreferences writes
  Timer? _saveTimer;
  static const Duration _saveDelay = Duration(milliseconds: 500);
  bool _isDisposed = false;

  // Getters
  String get apiEndpoint => _apiEndpoint;
  String get websocketEndpoint => _websocketEndpoint;
  ThemeMode get themeMode {
    if (_themeMode == 'light') {
      return ThemeMode.light;
    } else if (_themeMode == 'dark') {
      return ThemeMode.dark;
    }
    return ThemeMode.system;
  }

  String get themeModeName => _themeMode;
  String get pttMode => _pttMode;
  bool get magicMicEnabled => _magicMicEnabled;
  bool get isLoaded => _isLoaded;

  static const List<Map<String, String>> predefinedEndpoints = [
    {
      'name': 'Stable',
      'api': 'http://192.9.165.5:8000',
      'websocket': 'http://192.9.165.5:8000/msg',
    },
    // {
    //   'name': 'Staging',
    //   'api': 'https://staging-api.operationwon.com',
    //   'websocket': 'wss://staging-api.operationwon.com/msg',
    // },
  ];

  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      _apiEndpoint = _prefs?.getString(_apiEndpointKey) ?? _defaultApiEndpoint;
      _websocketEndpoint =
          _prefs?.getString(_websocketEndpointKey) ?? _defaultWebsocketEndpoint;
      _themeMode = _prefs?.getString(_themeModeKey) ?? _defaultThemeMode;
      _pttMode = _prefs?.getString(_pttModeKey) ?? _defaultPttMode;
      _magicMicEnabled =
          _prefs?.getBool(_magicMicKey) ?? _defaultMagicMicEnabled;

      debugPrint('SettingsProvider: Loaded API endpoint: $_apiEndpoint');
      debugPrint(
          'SettingsProvider: Loaded WebSocket endpoint: $_websocketEndpoint');

      _isLoaded = true;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isLoaded = true;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set API endpoint
  Future<void> setApiEndpoint(String endpoint) async {
    if (_apiEndpoint != endpoint) {
      _apiEndpoint = endpoint;
      _debouncedSave(_apiEndpointKey, endpoint);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set WebSocket endpoint
  Future<void> setWebsocketEndpoint(String endpoint) async {
    if (_websocketEndpoint != endpoint) {
      _websocketEndpoint = endpoint;
      _debouncedSave(_websocketEndpointKey, endpoint);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set both API and WebSocket endpoints from predefined option
  Future<void> setPredefinedEndpoint(Map<String, String> endpoint) async {
    final apiUrl = endpoint['api']!;
    final wsUrl = endpoint['websocket']!;

    bool hasChanges = false;

    if (_apiEndpoint != apiUrl) {
      _apiEndpoint = apiUrl;
      await _prefs?.setString(_apiEndpointKey, apiUrl);
      hasChanges = true;
    }

    if (_websocketEndpoint != wsUrl) {
      _websocketEndpoint = wsUrl;
      await _prefs?.setString(_websocketEndpointKey, wsUrl);
      hasChanges = true;
    }

    if (hasChanges) {
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set theme mode
  Future<void> setThemeMode(String mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      _debouncedSave(_themeModeKey, mode);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set PTT mode
  Future<void> setPttMode(String mode) async {
    if (_pttMode != mode) {
      _pttMode = mode;
      _debouncedSave(_pttModeKey, mode);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Set Magic Mic enabled state
  Future<void> setMagicMicEnabled(bool enabled) async {
    if (_magicMicEnabled != enabled) {
      _magicMicEnabled = enabled;
      _debouncedSave(_magicMicKey, enabled);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _apiEndpoint = _defaultApiEndpoint;
    _websocketEndpoint = _defaultWebsocketEndpoint;
    _themeMode = _defaultThemeMode;
    _pttMode = _defaultPttMode;
    _magicMicEnabled = _defaultMagicMicEnabled;

    await _prefs?.clear();
    debugPrint(
        'SettingsProvider: Reset to defaults - API: $_apiEndpoint, WS: $_websocketEndpoint');
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Clear cached endpoints to force use of defaults
  Future<void> clearEndpointCache() async {
    await _prefs?.remove(_apiEndpointKey);
    await _prefs?.remove(_websocketEndpointKey);
    _apiEndpoint = _defaultApiEndpoint;
    _websocketEndpoint = _defaultWebsocketEndpoint;
    debugPrint(
        'SettingsProvider: Cleared endpoint cache - API: $_apiEndpoint, WS: $_websocketEndpoint');
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Get current predefined endpoint (if any)
  Map<String, String>? getCurrentPredefinedEndpoint() {
    for (final endpoint in predefinedEndpoints) {
      if (endpoint['api'] == _apiEndpoint &&
          endpoint['websocket'] == _websocketEndpoint) {
        return endpoint;
      }
    }
    return null;
  }

  // Check if using custom endpoint
  bool get isUsingCustomEndpoint => getCurrentPredefinedEndpoint() == null;

  // Debounced save method to prevent excessive SharedPreferences writes
  void _debouncedSave(String key, dynamic value) {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () async {
      await _saveToPreferences(key, value);
    });
  }

  // Save to SharedPreferences
  Future<void> _saveToPreferences(String key, dynamic value) async {
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return; // Prevent duplicate disposal

    _saveTimer?.cancel();
    _isDisposed = true;

    try {
      super.dispose();
    } catch (e) {
      // Ignore disposal errors during hot reload
      debugPrint(
          '[SettingsProvider] Ignoring disposal error during hot reload: $e');
    }
  }
}
