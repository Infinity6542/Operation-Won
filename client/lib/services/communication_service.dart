import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/settings_provider.dart';
import 'websocket_service.dart';
import 'audio_service.dart';
import 'permission_service.dart';
import 'encryption_service.dart';

class CommunicationService extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final WebSocketService _webSocketService = WebSocketService();
  final EncryptionService _encryptionService = EncryptionService();
  late final AudioService _audioService;

  StreamSubscription? _audioDataSubscription;
  StreamSubscription? _incomingAudioSubscription;
  Timer? _notificationDebounceTimer;
  bool _isDisposed = false;

  bool _isPTTActive = false;
  bool _isPTTToggleMode = false; // true for tap mode, false for hold mode
  bool _isPersistentRecording =
      true; // Track if mic is persistently active in channel
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
  bool get isEncryptionReady =>
      _currentChannelId != null &&
      _encryptionService.isChannelEncryptionReady(_currentChannelId!);
  EncryptionStatus get encryptionStatus => _currentChannelId != null
      ? _encryptionService.getChannelEncryptionStatus(_currentChannelId!)
      : EncryptionStatus.disabled;

  CommunicationService(this._settingsProvider) {
    // Initialize audio service based on platform
    if (kIsWeb) {
      _audioService = WebAudioService();
    } else {
      _audioService = AudioService();
    }

    _setupListeners();
    _initializeConnection();
    _initializeEncryption();
  }

  // Debounced notification to prevent excessive UI rebuilds
  void _debouncedNotify() {
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      // Guard against notifications after disposal
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  Future<void> _initializeEncryption() async {
    await _encryptionService.initialize();
    debugPrint('[Comm] Encryption service initialized');
  }

  void _setupListeners() {
    // Listen to settings changes for endpoint updates
    _settingsProvider.addListener(_onSettingsChanged);

    // Listen to WebSocket service changes
    _webSocketService.addListener(() {
      _debouncedNotify();
    });

    // Set PTT active callback to prevent reconnection during PTT
    _webSocketService.setPTTActiveCallback(() => _isPTTActive);

    // Set encryption-related callbacks
    _webSocketService.setKeyExchangeCallback(processKeyExchange);
    _webSocketService.setEncryptedAudioCallback(_onEncryptedAudioReceived);

    // Listen to audio service changes
    _audioService.addListener(() {
      _debouncedNotify();
    });

    // Listen to encryption service changes
    _encryptionService.addListener(() {
      _debouncedNotify();
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

    // Enable wakelock to keep the app active when screen is off
    try {
      await WakelockPlus.enable();
      debugPrint(
          '[Comm] Wakelock enabled - app will stay active with screen off');
    } catch (e) {
      debugPrint('[Comm] Failed to enable wakelock: $e');
    }

    // Start audio playing mode to receive audio
    await _audioService.startPlaying();

    // Start persistent microphone recording when joining channel
    final recordingStarted = await _audioService.startRecording();
    if (recordingStarted) {
      _isPersistentRecording = true;
      debugPrint(
          '[Comm] Persistent microphone recording started for channel: $channelId');
    } else {
      debugPrint('[Comm] Failed to start persistent microphone recording');
    }

    debugPrint('[Comm] Joined channel: $channelId');
    notifyListeners(); // Keep immediate for channel changes
  }

  // Join a specific channel with encryption setup
  Future<void> joinChannelWithEncryption(String channelId) async {
    // First join the channel normally
    await joinChannel(channelId);

    // Then setup encryption for the channel
    await setupChannelEncryption(channelId);

    debugPrint('[Comm] Joined channel with encryption: $channelId');
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

    // Disable wakelock when leaving channel to save battery
    try {
      await WakelockPlus.disable();
      debugPrint('[Comm] Wakelock disabled - device can sleep normally');
    } catch (e) {
      debugPrint('[Comm] Failed to disable wakelock: $e');
    }

    // Clear channel ID first to prevent duplicate calls
    final channelId = _currentChannelId;
    _currentChannelId = null;

    // Clear encryption data for the channel
    if (channelId != null) {
      await _encryptionService.clearChannelEncryption(channelId);
    }

    // Disconnect WebSocket when leaving channel to prevent reconnection attempts
    await _webSocketService.disconnect();

    debugPrint('[Comm] Left channel $channelId and disconnected WebSocket');
    notifyListeners(); // Keep immediate for channel changes
  }

  // Set up encryption for a channel
  Future<bool> setupChannelEncryption(String channelId) async {
    debugPrint('[Comm] Setting up encryption for channel: $channelId');

    try {
      // For now, pass empty user list - in production, get actual channel members
      final success =
          await _encryptionService.setupChannelEncryption(channelId, []);
      if (success) {
        debugPrint('[Comm] Channel encryption setup initiated for $channelId');

        // Get our public key to broadcast
        final keyPair = await _encryptionService.generateKeyPair();
        final publicKeyBase64 =
            _encryptionService.encodePublicKey(keyPair.publicKey);

        // Send key exchange via WebSocket
        _webSocketService.sendSignal('key_exchange', {
          'channelId': channelId,
          'publicKey': publicKeyBase64,
        });

        debugPrint('[Comm] Sent key exchange for channel $channelId');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Comm] Failed to setup channel encryption: $e');
      return false;
    }
  }

  // Process incoming key exchange
  Future<void> processKeyExchange(
      String channelId, String userId, String publicKeyBase64) async {
    debugPrint(
        '[Comm] Processing key exchange for channel $channelId from user $userId');
    await _encryptionService.processKeyExchange(
        channelId, userId, publicKeyBase64);
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

    debugPrint(
        '[Comm] PTT started (persistent recording: $_isPersistentRecording)');
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

    debugPrint(
        '[Comm] PTT stopped (persistent recording: $_isPersistentRecording)');
  }

  // Handle outgoing audio data (from microphone)
  void _onAudioDataReceived(Uint8List audioData) {
    debugPrint(
        '[Comm] Received outgoing audio data: ${audioData.length} bytes (PTT active: $_isPTTActive, WebSocket connected: ${_webSocketService.isConnected})');

    if (_isPTTActive && _webSocketService.isConnected) {
      debugPrint('[Comm] Encoding and sending audio data to WebSocket');

      // First, encode the audio data
      _audioService.encodeAudioData(audioData).then((encodedData) async {
        if (encodedData != null) {
          // Then encrypt if encryption is ready
          if (_currentChannelId != null &&
              _encryptionService.isChannelEncryptionReady(_currentChannelId!)) {
            debugPrint(
                '[Comm] Encrypting encoded audio: ${encodedData.length} bytes');
            final encryptedChunk = await _encryptionService.encryptAudioChunk(
                encodedData, _currentChannelId!);
            if (encryptedChunk != null) {
              // Send encrypted audio chunk as JSON
              final encryptedJson = encryptedChunk.toJson();
              _webSocketService.sendSignal('encrypted_audio', encryptedJson);
              debugPrint(
                  '[Comm] Sent encrypted audio: ${encryptedChunk.encryptedData.length} bytes encrypted data');
            } else {
              debugPrint(
                  '[Comm] Encryption failed, sending unencrypted encoded data');
              _webSocketService.sendAudioData(encodedData);
            }
          } else {
            debugPrint(
                '[Comm] Encryption not ready, sending unencrypted encoded audio: ${encodedData.length} bytes');
            _webSocketService.sendAudioData(encodedData);
          }
        } else {
          debugPrint('[Comm] Encoding failed, sending unencoded data');
          _webSocketService.sendAudioData(audioData);
        }
      }).catchError((error) {
        debugPrint('[Comm] Failed to encode outgoing audio: $error');
        // Send raw data as fallback
        _webSocketService.sendAudioData(audioData);
      });
    } else {
      debugPrint(
          '[Comm] NOT sending audio - PTT not active or WebSocket not connected');
    }
  }

  // Handle incoming audio data (from other users)
  void _onIncomingAudioReceived(Uint8List audioData) {
    debugPrint(
        '[Comm] Received incoming audio data: ${audioData.length} bytes');

    // First check if this might be encrypted data by trying to parse as EncryptedAudioChunk
    // For now, assume unencrypted data - in a full implementation, we'd check message type

    // Decode audio data before playing (async operation)
    _audioService.decodeAudioData(audioData).then((decodedData) {
      if (decodedData != null) {
        debugPrint('[Comm] Playing decoded audio: ${decodedData.length} bytes');
        _audioService.playAudioChunk(decodedData);
      } else {
        debugPrint('[Comm] Failed to decode audio, playing unencoded fallback');
        _audioService.playAudioChunk(audioData);
      }
    }).catchError((error) {
      debugPrint('[Comm] Failed to decode incoming audio: $error');
      debugPrint(
          '[Comm] Playing unencoded audio as fallback: ${audioData.length} bytes');
      // Play unencoded as fallback
      _audioService.playAudioChunk(audioData);
    });
  }

  // Handle incoming encrypted audio data (called by WebSocket service for encrypted_audio signals)
  Future<void> _onEncryptedAudioReceived(
      Map<String, dynamic> encryptedAudioJson) async {
    if (_currentChannelId == null) {
      debugPrint('[Comm] Cannot decrypt audio - no current channel');
      return;
    }

    try {
      // Parse encrypted audio chunk from JSON
      final encryptedChunk = EncryptedAudioChunk.fromJson(encryptedAudioJson);
      debugPrint(
          '[Comm] Received encrypted audio: ${encryptedChunk.encryptedData.length} bytes encrypted data');

      // Decrypt the audio chunk
      final decryptedData = await _encryptionService.decryptAudioChunk(
          encryptedChunk, _currentChannelId!);
      if (decryptedData != null) {
        debugPrint('[Comm] Decrypted audio: ${decryptedData.length} bytes');

        // Decode the decrypted audio data (it's still Opus-encoded)
        final decodedData = await _audioService.decodeAudioData(decryptedData);
        if (decodedData != null) {
          debugPrint(
              '[Comm] Playing decrypted and decoded audio: ${decodedData.length} bytes');
          _audioService.playAudioChunk(decodedData);
        } else {
          debugPrint('[Comm] Failed to decode decrypted audio');
        }
      } else {
        debugPrint('[Comm] Failed to decrypt audio chunk');
      }
    } catch (e) {
      debugPrint('[Comm] Error processing encrypted audio: $e');
    }
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

  // Check if wakelock is currently enabled
  Future<bool> get isWakelockEnabled async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      debugPrint('[Comm] Failed to check wakelock status: $e');
      return false;
    }
  }

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
    _isDisposed = true;
    stopPTT();
    disconnectWebSocket();

    // Ensure wakelock is disabled when service is disposed
    WakelockPlus.disable().catchError((e) {
      debugPrint('[Comm] Failed to disable wakelock on dispose: $e');
    });

    _audioDataSubscription?.cancel();
    _incomingAudioSubscription?.cancel();
    _settingsProvider.removeListener(_onSettingsChanged);
    _notificationDebounceTimer?.cancel();
    _audioService.dispose();
    _webSocketService.dispose();
    super.dispose();
  }
}
