import 'dart:async';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';
import 'websocket_service.dart';
import 'audio_service.dart';
import 'permission_service.dart';

class CommunicationService extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final WebSocketService _webSocketService = WebSocketService();
  late final AudioService _audioService;

  StreamSubscription? _audioDataSubscription;
  StreamSubscription? _incomingAudioSubscription;

  bool _isPTTActive = false;
  bool _isPTTToggleMode = false; // true for tap mode, false for hold mode
  bool _isPersistentRecording = false; // Track if mic is persistently active in channel
  String? _currentChannelId;
  bool _isEmergencyMode = false;
  String? _previousChannelId; // Store previous channel for emergency exit

  // Getters
  bool get isConnected => _webSocketService.isConnected;
  bool get isPTTActive => _isPTTActive;
  bool get isRecording => _audioService.isRecording;
  bool get isPTTToggleMode => _isPTTToggleMode;
  bool get isEmergencyMode => _isEmergencyMode;
  bool get isPersistentRecording => _isPersistentRecording;
  String? get currentChannelId => _currentChannelId;

  CommunicationService(this._settingsProvider) {
    // Initialize audio service based on platform
    if (kIsWeb) {
      _audioService = WebAudioService();
    } else {
      _audioService = AudioService();
    }

    _setupListeners();
    _initializeConnection();
  }

  void _setupListeners() {
    // Listen to settings changes for endpoint updates
    _settingsProvider.addListener(_onSettingsChanged);

    // Listen to WebSocket service changes
    _webSocketService.addListener(() {
      notifyListeners();
    });

    // Set PTT active callback to prevent reconnection during PTT
    _webSocketService.setPTTActiveCallback(() => _isPTTActive);

    // Listen to audio service changes
    _audioService.addListener(() {
      notifyListeners();
    });

    // Listen to outgoing audio data (from microphone)
    _audioDataSubscription = _audioService.audioDataStream.listen(
      _onAudioDataReceived,
      onError: (error) {
        debugPrint('[Comm] Audio data stream error: $error');
      },
    );

    // Listen to incoming audio data (from WebSocket)
    _incomingAudioSubscription = _webSocketService.audioStream.listen(
      _onIncomingAudioReceived,
      onError: (error) {
        debugPrint('[Comm] Incoming audio stream error: $error');
      },
    );
  }

  void _onSettingsChanged() {
    // Update PTT mode from settings
    _isPTTToggleMode = _settingsProvider.pttMode == 'tap';

    // Update Magic Mic setting
    _updateMagicMicSetting();

    // Reconnect with new WebSocket endpoint if connected
    if (_webSocketService.isConnected) {
      _reconnectWebSocket();
    }
  }

  Future<void> _updateMagicMicSetting() async {
    final magicMicEnabled = _settingsProvider.magicMicEnabled;
    await _audioService.setMagicMicEnabled(magicMicEnabled);
    debugPrint('[Comm] Magic Mic ${magicMicEnabled ? 'enabled' : 'disabled'}');
  }

  Future<void> _initializeConnection() async {
    // Update PTT mode from current settings
    _isPTTToggleMode = _settingsProvider.pttMode == 'tap';

    // Set up audio configuration
    await _audioService.setAudioConfig(
      sampleRate: 48000, // High quality audio
      channels: 1, // Mono for voice communication
      bitRate: 64000, // Good quality for voice
    );

    // Set Magic Mic setting
    await _updateMagicMicSetting();

    // Connect to WebSocket if not already connected
    await connectWebSocket();
  }

  // Connect to WebSocket using current settings
  Future<bool> connectWebSocket() async {
    final wsUrl = _settingsProvider.websocketEndpoint;
    debugPrint(
        '[Comm] Connecting to WebSocket: $wsUrl (Channel: $_currentChannelId)');

    final success =
        await _webSocketService.connect(wsUrl, channelId: _currentChannelId);
    if (success) {
      debugPrint('[Comm] WebSocket connected successfully');
    } else {
      debugPrint('[Comm] Failed to connect to WebSocket');
    }

    return success;
  }

  // Disconnect from WebSocket
  Future<void> disconnectWebSocket() async {
    await _webSocketService.disconnect();
    debugPrint('[Comm] WebSocket disconnected');
  }

  // Reconnect WebSocket with current settings
  Future<void> _reconnectWebSocket() async {
    await disconnectWebSocket();
    await connectWebSocket();
  }

  // Join a specific channel
  Future<void> joinChannel(String channelId) async {
    if (!_webSocketService.isConnected) {
      await connectWebSocket();
    }

    _currentChannelId = channelId;
    await _webSocketService.joinChannel(channelId);

    // Start audio playing mode to receive audio
    await _audioService.startPlaying();
    
    // Start persistent microphone recording when joining channel
    final recordingStarted = await _audioService.startRecording();
    if (recordingStarted) {
      _isPersistentRecording = true;
      debugPrint('[Comm] Persistent microphone recording started for channel: $channelId');
    } else {
      debugPrint('[Comm] Failed to start persistent microphone recording');
    }

    debugPrint('[Comm] Joined channel: $channelId');
    notifyListeners();
  }

  // Leave current channel
  Future<void> leaveChannel() async {
    // Guard against multiple leave calls
    if (_currentChannelId == null) {
      debugPrint('[Comm] Already left channel, ignoring duplicate leave call');
      return;
    }

    debugPrint('[Comm] Leaving channel: $_currentChannelId');

    if (_isPTTActive) {
      await stopPTT();
    }

    // Stop persistent recording when leaving channel
    if (_isPersistentRecording) {
      await _audioService.stopRecording();
      _isPersistentRecording = false;
      debugPrint('[Comm] Stopped persistent microphone recording');
    }

    await _audioService.stopPlaying();
    
    // Clear channel ID first to prevent duplicate calls
    final channelId = _currentChannelId;
    _currentChannelId = null;

    // Disconnect WebSocket when leaving channel to prevent reconnection attempts
    await _webSocketService.disconnect();

    debugPrint('[Comm] Left channel $channelId and disconnected WebSocket');
    notifyListeners();
  }

  // Reconnect WebSocket with fresh authentication (useful after token refresh)
  Future<bool> reconnectWebSocket() async {
    try {
      debugPrint('[Comm] Reconnecting WebSocket with fresh authentication...');
      final success = await _webSocketService.reconnect();

      if (success) {
        debugPrint('[Comm] WebSocket reconnected successfully');

        // If we were in a channel, rejoin it
        if (_currentChannelId != null) {
          await _webSocketService.joinChannel(_currentChannelId!);
        }
      } else {
        debugPrint('[Comm] Failed to reconnect WebSocket');
      }

      return success;
    } catch (e) {
      debugPrint('[Comm] WebSocket reconnection error: $e');
      return false;
    }
  }

  // Start Push-to-Talk (PTT) - supports both hold and tap modes
  Future<bool> startPTT() async {
    if (!_webSocketService.isConnected || _currentChannelId == null) {
      debugPrint('[Comm] Cannot start PTT: not connected or no channel');
      return false;
    }

    if (_isPTTToggleMode) {
      // Tap mode - toggle PTT state
      if (_isPTTActive) {
        await stopPTT();
        return false;
      } else {
        return await _activatePTT();
      }
    } else {
      // Hold mode - start PTT
      return await _activatePTT();
    }
  }

  // Internal method to activate PTT
  Future<bool> _activatePTT() async {
    if (_isPTTActive) {
      debugPrint('[Comm] PTT already active');
      return true;
    }

    // Send PTT start signal
    _webSocketService.sendSignal('ptt start');

    // If persistent recording is not active, start recording for PTT
    if (!_isPersistentRecording) {
      final recordingStarted = await _audioService.startRecording();
      if (!recordingStarted) {
        debugPrint('[Comm] Failed to start audio recording for PTT');
        return false;
      }
    }

    _isPTTActive = true;
    notifyListeners();

    debugPrint('[Comm] PTT started (persistent recording: $_isPersistentRecording)');
    return true;
  } // Stop Push-to-Talk (PTT)

  Future<void> stopPTT() async {
    if (!_isPTTActive) return;

    // If persistent recording is not active, stop recording
    if (!_isPersistentRecording) {
      await _audioService.stopRecording();
    }

    // Send PTT stop signal
    _webSocketService.sendSignal('ptt stop');

    _isPTTActive = false;
    notifyListeners();

    debugPrint('[Comm] PTT stopped (persistent recording: $_isPersistentRecording)');
  }

  // Handle outgoing audio data (from microphone)
  void _onAudioDataReceived(Uint8List audioData) {
    if (_isPTTActive && _webSocketService.isConnected) {
      _webSocketService.sendAudioData(audioData);
    }
  }

  // Handle incoming audio data (from other users)
  void _onIncomingAudioReceived(Uint8List audioData) {
    // Play the received audio chunk
    _audioService.playAudioChunk(audioData);
  }

  // Test connection
  Future<bool> testConnection() async {
    try {
      final wsUrl = _settingsProvider.websocketEndpoint;

      // Try to connect temporarily
      final tempService = WebSocketService();
      final success = await tempService.connect(wsUrl);

      if (success) {
        await tempService.disconnect();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[Comm] Connection test failed: $e');
      return false;
    }
  }

  // Check microphone permission
  Future<bool> checkMicrophonePermission() async {
    // First check using the new permission service
    final hasPermission = await PermissionService.hasMicrophonePermission();
    if (hasPermission) {
      return true;
    }

    // Fallback to audio service if needed
    return await _audioService.requestMicrophonePermission();
  }

  // E2EE Key Management
  Future<Uint8List?> generateE2EEKey() async {
    return await _audioService.generateNewE2EEKey();
  }

  Future<bool> setE2EEKey(Uint8List keyBytes) async {
    return await _audioService.setE2EEKey(keyBytes);
  }

  Uint8List? getE2EEKey() {
    return _audioService.getE2EEKey();
  }

  bool get hasE2EEKey => _audioService.hasE2EEKey;

  // Magic Mic status
  bool get isMagicMicEnabled => _audioService.magicMicEnabled;

  // Join emergency channel (overrides current channel)
  Future<void> joinEmergencyChannel() async {
    const emergencyChannelId = 'EMERGENCY';

    if (_currentChannelId != null && _currentChannelId != emergencyChannelId) {
      _previousChannelId = _currentChannelId;
    }

    _isEmergencyMode = true;
    await joinChannel(emergencyChannelId);

    debugPrint('[Comm] Joined emergency channel');
  }

  // Exit emergency mode and return to previous channel
  Future<void> exitEmergencyMode() async {
    if (!_isEmergencyMode) return;

    _isEmergencyMode = false;

    if (_previousChannelId != null) {
      await joinChannel(_previousChannelId!);
      _previousChannelId = null;
    } else {
      await leaveChannel();
    }

    debugPrint('[Comm] Exited emergency mode');
  }

  @override
  void dispose() {
    stopPTT();
    disconnectWebSocket();
    _audioDataSubscription?.cancel();
    _incomingAudioSubscription?.cancel();
    _settingsProvider.removeListener(_onSettingsChanged);
    _audioService.dispose();
    _webSocketService.dispose();
    super.dispose();
  }
}
