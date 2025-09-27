import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'secure_storage_service.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String? _currentUrl;
  String? _currentChannelId;
  Timer? _heartbeatTimer;
  Timer? _connectionHealthTimer;
  DateTime? _lastMessageReceived;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _intentionalDisconnect = false; // Track intentional disconnections

  // Callback to check if PTT is active (to prevent reconnection during PTT)
  bool Function()? _isPTTActiveCallback;

  // Callbacks for encryption-related signals
  Future<void> Function(String channelId, String userId, String publicKey)?
      _onKeyExchangeCallback;
  Future<void> Function(Map<String, dynamic> encryptedAudioJson)?
      _onEncryptedAudioCallback;

  // Audio stream controller for received audio data
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  // Connection status
  bool get isConnected => _isConnected;
  String? get currentChannelId => _currentChannelId;

  // Audio stream getter
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  // Set callback to check PTT active status (prevents reconnection during PTT)
  void setPTTActiveCallback(bool Function()? callback) {
    _isPTTActiveCallback = callback;
  }

  // Set callback for key exchange signals
  void setKeyExchangeCallback(
      Future<void> Function(String channelId, String userId, String publicKey)?
          callback) {
    _onKeyExchangeCallback = callback;
  }

  // Set callback for encrypted audio signals
  void setEncryptedAudioCallback(
      Future<void> Function(Map<String, dynamic> encryptedAudioJson)?
          callback) {
    _onEncryptedAudioCallback = callback;
  }

  // Convert HTTP URL to WebSocket URL if needed
  String _convertToWebSocketUrl(String url) {
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'ws://');
    }
    // Already a WebSocket URL or other scheme
    return url;
  }

  // Connect to WebSocket with JWT authentication
  Future<bool> connect(String url, {String? channelId}) async {
    try {
      await disconnect(); // Disconnect existing connection

      // Get JWT token for authentication
      final token = await SecureStorageService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WebSocket] No valid token available for authentication');
        _isConnected = false;
        notifyListeners();
        return false;
      }

      // Convert HTTP URL to WebSocket URL if needed
      final websocketUrl = _convertToWebSocketUrl(url);
      debugPrint(
          '[WebSocket] Original URL: $url, WebSocket URL: $websocketUrl');

      // Add token and channel as query parameters
      final uri = Uri.parse(websocketUrl);
      final authenticatedUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
        if (channelId != null) 'channel': channelId,
      });

      _currentUrl = authenticatedUri.toString();
      _channel = WebSocketChannel.connect(authenticatedUri);

      // Listen to the WebSocket stream
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _reconnectAttempts =
          0; // Reset reconnect attempts on successful connection
      _intentionalDisconnect = false; // Reset intentional disconnect flag
      if (channelId != null) {
        _currentChannelId = channelId;
      }

      // Start heartbeat to keep connection alive
      _startHeartbeat();

      // Start connection health monitoring
      _startConnectionHealthCheck();

      notifyListeners();

      debugPrint('[WebSocket] Connected to $websocketUrl with authentication');
      return true;
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Disconnect from WebSocket
  Future<void> disconnect() async {
    _intentionalDisconnect = true; // Mark as intentional disconnect
    _stopHeartbeat();
    _stopConnectionHealthCheck();
    _reconnectAttempts = 0; // Reset reconnect attempts on manual disconnect

    if (_channel != null) {
      await _subscription?.cancel();
      await _channel!.sink.close(status.goingAway);
      _channel = null;
      _subscription = null;
    }

    _isConnected = false;
    _currentChannelId = null;
    notifyListeners();

    debugPrint('[WebSocket] Disconnected intentionally');
  }

  // Reconnect with fresh authentication (useful after token refresh)
  Future<bool> reconnect() async {
    if (_currentUrl == null) {
      debugPrint('[WebSocket] Cannot reconnect: no previous URL');
      return false;
    }

    // Reset reconnection attempts since this is a manual reconnect with fresh auth
    _reconnectAttempts = 0;

    // Extract base URL without query parameters
    final uri = Uri.parse(_currentUrl!);
    final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';

    return await connect(baseUrl, channelId: _currentChannelId);
  }

  // Join a channel (reconnects with new channel if needed)
  Future<bool> joinChannel(String channelId) async {
    if (_currentUrl == null) {
      debugPrint('[WebSocket] Cannot join channel: not connected');
      return false;
    }

    // If already connected, send channel change signal
    if (_isConnected && _currentChannelId != channelId) {
      sendSignal('channel_change', {'new_channel_id': channelId});
    }

    _currentChannelId = channelId;
    notifyListeners();
    debugPrint('[WebSocket] Joined channel: $channelId');
    return true;
  }

  // Leave current channel but keep WebSocket connection
  void leaveChannelOnly() {
    if (_currentChannelId != null) {
      debugPrint('[WebSocket] Left channel: $_currentChannelId');
      _currentChannelId = null;
      notifyListeners();
    }
  }

  // Send text signal (like PTT start/stop)
  void sendSignal(String type, [Map<String, dynamic>? payload]) {
    if (!_isConnected || _channel == null) return;

    final signal = {
      'type': type,
      if (payload != null) 'payload': payload,
    };

    try {
      _channel!.sink.add(jsonEncode(signal));
      debugPrint('[WebSocket] Sent signal: $type');
    } catch (e) {
      debugPrint('[WebSocket] Failed to send signal: $e');
    }
  }

  // Send audio data
  void sendAudioData(Uint8List audioData) {
    if (!_isConnected || _channel == null) return;

    try {
      _channel!.sink.add(audioData);
      debugPrint('[WebSocket] Sent audio chunk: ${audioData.length} bytes');
    } catch (e) {
      debugPrint('[WebSocket] Failed to send audio data: $e');
    }
  }

  // Handle incoming messages
  void _handleMessage(dynamic message) {
    _lastMessageReceived = DateTime.now();

    if (message is String) {
      // Text message - likely a signal
      try {
        final signal = jsonDecode(message);
        _handleSignal(signal);
      } catch (e) {
        debugPrint('[WebSocket] Failed to parse text message: $e');
      }
    } else if (message is List<int>) {
      // Binary message - audio data
      final audioData = Uint8List.fromList(message);
      _audioStreamController.add(audioData);
      debugPrint('[WebSocket] Received audio chunk: ${audioData.length} bytes');
    }
  }

  // Handle signals from server
  void _handleSignal(Map<String, dynamic> signal) {
    final type = signal['type'] as String?;
    debugPrint('[WebSocket] Received signal: $type');

    switch (type) {
      case 'user_joined':
        // Handle user joined channel
        break;
      case 'user_left':
        // Handle user left channel
        break;
      case 'channel_changed':
        // Handle channel change
        break;
      case 'key_exchange':
        _handleKeyExchange(signal);
        break;
      case 'encrypted_audio':
        _handleEncryptedAudio(signal);
        break;
      default:
        debugPrint('[WebSocket] Unknown signal type: $type');
    }
  }

  // Handle key exchange signals
  void _handleKeyExchange(Map<String, dynamic> signal) {
    try {
      final payload = signal['payload'] as Map<String, dynamic>?;
      if (payload != null && _onKeyExchangeCallback != null) {
        final channelId = payload['channelId'] as String?;
        final userId = payload['userId'] as String?;
        final publicKey = payload['publicKey'] as String?;

        if (channelId != null && userId != null && publicKey != null) {
          _onKeyExchangeCallback!(channelId, userId, publicKey);
        }
      }
    } catch (e) {
      debugPrint('[WebSocket] Error handling key exchange: $e');
    }
  }

  // Handle encrypted audio signals
  void _handleEncryptedAudio(Map<String, dynamic> signal) {
    try {
      final payload = signal['payload'] as Map<String, dynamic>?;
      if (payload != null && _onEncryptedAudioCallback != null) {
        _onEncryptedAudioCallback!(payload);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error handling encrypted audio: $e');
    }
  }

  // Handle connection errors
  void _handleError(dynamic error) {
    debugPrint('[WebSocket] Connection error: $error');

    // Check if this is an authentication error
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('invalid token') ||
        errorString.contains('revoked') ||
        errorString.contains('authentication')) {
      debugPrint(
          '[WebSocket] Authentication failed - token may be revoked/invalid');
      debugPrint(
          '[WebSocket] Stopping reconnection attempts due to auth failure');
      _reconnectAttempts =
          _maxReconnectAttempts; // Prevent further reconnection attempts
      _isConnected = false;
      notifyListeners();
      return;
    }

    // For other errors, attempt reconnection
    debugPrint('[WebSocket] Network error detected, will attempt reconnection');
    _handleConnectionFailure(); // This will handle setting _isConnected = false
  }

  // Handle disconnection
  void _handleDisconnect() {
    debugPrint('[WebSocket] Connection closed');
    _stopHeartbeat();
    _stopConnectionHealthCheck();

    if (_isConnected && !_intentionalDisconnect) {
      // This was an unexpected disconnection, attempt to reconnect
      debugPrint('[WebSocket] Unexpected disconnection detected');
      _handleConnectionFailure();
    } else {
      // This was an intentional disconnection or already disconnected
      debugPrint(
          '[WebSocket] Intentional disconnection or already disconnected');
      _isConnected = false;
      _currentChannelId = null;
      _intentionalDisconnect = false; // Reset the flag
      notifyListeners();
    }
  }

  // Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat(); // Clear any existing timer

    // The server sends protocol-level WebSocket pings every ~54 seconds
    // We don't need to send custom application-level pings since the server
    // handles this with proper WebSocket ping/pong frames.
    // Instead, we just monitor connection health by checking if we're still receiving data
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        // Just verify the connection is still active
        // The server will send protocol-level pings that keep the connection alive
        debugPrint('[WebSocket] Connection health check - still connected');
      } else {
        timer.cancel();
        debugPrint('[WebSocket] Connection health check - connection lost');
      }
    });
  }

  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Start connection health monitoring
  void _startConnectionHealthCheck() {
    _stopConnectionHealthCheck();
    _lastMessageReceived = DateTime.now();

    // Check connection health every 35 seconds (after server's 30-second timeout)
    _connectionHealthTimer =
        Timer.periodic(const Duration(seconds: 35), (timer) {
      if (_isConnected && _lastMessageReceived != null) {
        final timeSinceLastMessage =
            DateTime.now().difference(_lastMessageReceived!);

        // If we haven't received any message in 40 seconds, consider connection dead
        if (timeSinceLastMessage.inSeconds > 40) {
          debugPrint(
              '[WebSocket] No messages received for ${timeSinceLastMessage.inSeconds}s, connection may be dead');
          _handleConnectionFailure();
        }
      } else if (!_isConnected) {
        timer.cancel();
      }
    });
  }

  // Stop connection health timer
  void _stopConnectionHealthCheck() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  // Handle connection failure and attempt reconnection
  void _handleConnectionFailure() {
    debugPrint(
        '[WebSocket] Connection failure detected, attempting reconnection...');
    _isConnected = false;
    notifyListeners();

    // Check if PTT is active - if so, defer reconnection
    if (_isPTTActiveCallback?.call() == true) {
      debugPrint('[WebSocket] PTT is active, deferring reconnection attempt');
      // Schedule a retry in 2 seconds to check again
      Timer(const Duration(seconds: 2), () {
        if (!_isConnected) {
          _handleConnectionFailure();
        }
      });
      return;
    }

    // Check if we should attempt reconnection
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WebSocket] Max reconnection attempts reached, giving up');
      return;
    }

    _reconnectAttempts++;

    // Exponential backoff: 2, 4, 8, 16, 32 seconds
    final delaySeconds = (2 * (_reconnectAttempts - 1)).clamp(2, 32);

    debugPrint(
        '[WebSocket] Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySeconds}s');

    Timer(Duration(seconds: delaySeconds), () async {
      if (!_isConnected && _currentUrl != null) {
        // Double-check PTT status before attempting reconnection
        if (_isPTTActiveCallback?.call() == true) {
          debugPrint('[WebSocket] PTT still active, deferring reconnection');
          // Schedule another check
          Timer(const Duration(seconds: 2), () {
            if (!_isConnected) {
              _handleConnectionFailure();
            }
          });
          return;
        }

        // Check if we have a valid token before attempting reconnection
        final token = await SecureStorageService.getToken();
        if (token == null || token.isEmpty) {
          debugPrint('[WebSocket] No valid token available for authentication');
          debugPrint('[WebSocket] Automatic reconnection failed');
          return;
        }

        final uri = Uri.parse(_currentUrl!);
        final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
        final success = await connect(baseUrl, channelId: _currentChannelId);
        if (success) {
          debugPrint('[WebSocket] Automatic reconnection successful');
        } else {
          debugPrint('[WebSocket] Automatic reconnection failed');
          // Will trigger another attempt if under the limit
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _handleConnectionFailure();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    disconnect();
    _audioStreamController.close();
    super.dispose();
  }
}
