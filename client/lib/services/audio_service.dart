import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('operation_won/audio');
  
  bool _isRecording = false;
  bool _isPlaying = false;
  StreamSubscription? _audioStreamSubscription;
  
  // Audio recording stream controller
  final StreamController<Uint8List> _audioDataController = 
      StreamController<Uint8List>.broadcast();
  
  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  
  AudioService() {
    _setupMethodCallHandler();
  }
  
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAudioData':
          final audioData = call.arguments as Uint8List;
          _audioDataController.add(audioData);
          break;
        case 'onRecordingError':
          final error = call.arguments as String;
          debugPrint('[Audio] Recording error: $error');
          _isRecording = false;
          notifyListeners();
          break;
        default:
          debugPrint('[Audio] Unknown method call: ${call.method}');
      }
    });
  }
  
  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final result = await _channel.invokeMethod('requestMicrophonePermission');
      return result as bool;
    } catch (e) {
      debugPrint('[Audio] Failed to request microphone permission: $e');
      return false;
    }
  }
  
  // Start recording audio
  Future<bool> startRecording() async {
    try {
      if (_isRecording) return true;
      
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        debugPrint('[Audio] Microphone permission denied');
        return false;
      }
      
      final result = await _channel.invokeMethod('startRecording');
      _isRecording = result as bool;
      notifyListeners();
      
      debugPrint('[Audio] Recording started: $_isRecording');
      return _isRecording;
    } catch (e) {
      debugPrint('[Audio] Failed to start recording: $e');
      return false;
    }
  }
  
  // Stop recording audio
  Future<void> stopRecording() async {
    try {
      if (!_isRecording) return;
      
      await _channel.invokeMethod('stopRecording');
      _isRecording = false;
      notifyListeners();
      
      debugPrint('[Audio] Recording stopped');
    } catch (e) {
      debugPrint('[Audio] Failed to stop recording: $e');
    }
  }
  
  // Play audio chunk
  Future<void> playAudioChunk(Uint8List audioData) async {
    try {
      await _channel.invokeMethod('playAudioChunk', audioData);
      debugPrint('[Audio] Playing audio chunk: ${audioData.length} bytes');
    } catch (e) {
      debugPrint('[Audio] Failed to play audio chunk: $e');
    }
  }
  
  // Start playing mode (prepare for incoming audio)
  Future<void> startPlaying() async {
    try {
      await _channel.invokeMethod('startPlaying');
      _isPlaying = true;
      notifyListeners();
      
      debugPrint('[Audio] Playing mode started');
    } catch (e) {
      debugPrint('[Audio] Failed to start playing mode: $e');
    }
  }
  
  // Stop playing mode
  Future<void> stopPlaying() async {
    try {
      await _channel.invokeMethod('stopPlaying');
      _isPlaying = false;
      notifyListeners();
      
      debugPrint('[Audio] Playing mode stopped');
    } catch (e) {
      debugPrint('[Audio] Failed to stop playing mode: $e');
    }
  }
  
  // Set audio configuration
  Future<void> setAudioConfig({
    int sampleRate = 48000,
    int channels = 1,
    int bitRate = 64000,
  }) async {
    try {
      await _channel.invokeMethod('setAudioConfig', {
        'sampleRate': sampleRate,
        'channels': channels,
        'bitRate': bitRate,
      });
      
      debugPrint('[Audio] Audio config set: $sampleRate Hz, $channels ch, $bitRate bps');
    } catch (e) {
      debugPrint('[Audio] Failed to set audio config: $e');
    }
  }
  
  @override
  void dispose() {
    stopRecording();
    stopPlaying();
    _audioDataController.close();
    _audioStreamSubscription?.cancel();
    super.dispose();
  }
}

// Fallback implementation for platforms without native audio support
class WebAudioService extends AudioService {
  @override
  Future<bool> requestMicrophonePermission() async {
    // For web, we can try to access microphone directly
    return true;
  }
  
  @override
  Future<bool> startRecording() async {
    // Web implementation would use MediaRecorder API
    debugPrint('[Audio] Web audio recording not yet implemented');
    return false;
  }
  
  @override
  Future<void> playAudioChunk(Uint8List audioData) async {
    // Web implementation would use Web Audio API
    debugPrint('[Audio] Web audio playback not yet implemented');
  }
}
