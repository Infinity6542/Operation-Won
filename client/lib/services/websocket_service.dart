import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'secure_storage_service.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  String? _currentUrl;
  bool _isConnected = false;
  String? _currentChannelId;
  StreamSubscription? _subscription;

  // Audio data stream controller
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  // Connection status
  bool get isConnected => _isConnected;
  String? get currentChannelId => _currentChannelId;

  // Audio stream getter
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  // Connect to WebSocket with JWT authentication
  Future<bool> connect(String url, {String? channelId}) async {
    try {
      await disconnect(); // Disconnect existing connection

      // Get JWT token for authentication
      final token = await SecureStorageService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WebSocket] No valid token available for authentication');
        return false;
      }

      // Add token and channel as query parameters
      final uri = Uri.parse(url);
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
      if (channelId != null) {
        _currentChannelId = channelId;
      }
      notifyListeners();

      debugPrint('[WebSocket] Connected to $url with authentication');
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
    if (_channel != null) {
      await _subscription?.cancel();
      await _channel!.sink.close(status.goingAway);
      _channel = null;
      _subscription = null;
    }

    _isConnected = false;
    _currentChannelId = null;
    notifyListeners();

    debugPrint('[WebSocket] Disconnected');
  }

  // Reconnect with fresh authentication (useful after token refresh)
  Future<bool> reconnect() async {
    if (_currentUrl == null) {
      debugPrint('[WebSocket] Cannot reconnect: no previous URL');
      return false;
    }

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
      default:
        debugPrint('[WebSocket] Unknown signal type: $type');
    }
  }

  // Handle connection errors
  void _handleError(dynamic error) {
    debugPrint('[WebSocket] Connection error: $error');
    
    // Check if this is an authentication error
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('401') || 
        errorString.contains('unauthorized') || 
        errorString.contains('invalid token')) {
      debugPrint('[WebSocket] Authentication failed - token may be expired');
      // The communication service should handle token refresh and reconnection
    }
    
    _isConnected = false;
    notifyListeners();
  }

  // Handle disconnection
  void _handleDisconnect() {
    debugPrint('[WebSocket] Connection closed');
    _isConnected = false;
    _currentChannelId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _audioStreamController.close();
    super.dispose();
  }
}
