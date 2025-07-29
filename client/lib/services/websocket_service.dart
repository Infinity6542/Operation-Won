import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

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
  
  // Connect to WebSocket
  Future<bool> connect(String url) async {
    try {
      await disconnect(); // Disconnect existing connection
      
      _currentUrl = url;
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Listen to the WebSocket stream
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      _isConnected = true;
      notifyListeners();
      
      debugPrint('[WebSocket] Connected to $url');
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
  
  // Join a channel
  void joinChannel(String channelId) {
    _currentChannelId = channelId;
    notifyListeners();
    debugPrint('[WebSocket] Joined channel: $channelId');
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
  
  // Reconnect to the same URL
  Future<bool> reconnect() async {
    if (_currentUrl != null) {
      return await connect(_currentUrl!);
    }
    return false;
  }
  
  @override
  void dispose() {
    disconnect();
    _audioStreamController.close();
    super.dispose();
  }
}
