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
  static const String _defaultApiEndpoint = 'http://192.168.3.45:8000';
  static const String _defaultWebsocketEndpoint = 'ws://192.168.3.45:8000/msg';
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

  // Predefined API endpoints for easy switching
  static const List<Map<String, String>> predefinedEndpoints = [
    {
      'name': 'Local Development',
      'api': 'http://localhost:8000',
      'websocket': 'ws://localhost:8000/msg',
    },
    {
      'name': 'Android Emulator',
      'api': 'http://10.0.2.2:8000',
      'websocket': 'ws://10.0.2.2:8000/msg',
    },
    {
      'name': 'Local Network (Current)',
      'api': 'http://192.168.3.45:8000',
      'websocket': 'ws://192.168.3.45:8000/msg',
    },
    {
      'name': 'Local Network (WiFi)',
      'api': 'http://192.168.1.100:8000',
      'websocket': 'ws://192.168.1.100:8000/msg',
    },
    {
      'name': 'Production Server',
      'api': 'https://api.operationwon.com',
      'websocket': 'wss://api.operationwon.com/msg',
    },
    {
      'name': 'Staging Server',
      'api': 'https://staging-api.operationwon.com',
      'websocket': 'wss://staging-api.operationwon.com/msg',
    },
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Set API endpoint
  Future<void> setApiEndpoint(String endpoint) async {
    if (_apiEndpoint != endpoint) {
      _apiEndpoint = endpoint;
      _debouncedSave(_apiEndpointKey, endpoint);
      notifyListeners();
    }
  }

  // Set WebSocket endpoint
  Future<void> setWebsocketEndpoint(String endpoint) async {
    if (_websocketEndpoint != endpoint) {
      _websocketEndpoint = endpoint;
      _debouncedSave(_websocketEndpointKey, endpoint);
      notifyListeners();
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
      notifyListeners();
    }
  }

  // Set theme mode
  Future<void> setThemeMode(String mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      _debouncedSave(_themeModeKey, mode);
      notifyListeners();
    }
  }

  // Set PTT mode
  Future<void> setPttMode(String mode) async {
    if (_pttMode != mode) {
      _pttMode = mode;
      _debouncedSave(_pttModeKey, mode);
      notifyListeners();
    }
  }

  // Set Magic Mic enabled state
  Future<void> setMagicMicEnabled(bool enabled) async {
    if (_magicMicEnabled != enabled) {
      _magicMicEnabled = enabled;
      _debouncedSave(_magicMicKey, enabled);
      notifyListeners();
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
    notifyListeners();
  }

  // Clear cached endpoints to force use of defaults
  Future<void> clearEndpointCache() async {
    await _prefs?.remove(_apiEndpointKey);
    await _prefs?.remove(_websocketEndpointKey);
    _apiEndpoint = _defaultApiEndpoint;
    _websocketEndpoint = _defaultWebsocketEndpoint;
    debugPrint(
        'SettingsProvider: Cleared endpoint cache - API: $_apiEndpoint, WS: $_websocketEndpoint');
    notifyListeners();
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
    _saveTimer?.cancel();
    super.dispose();
  }
}
