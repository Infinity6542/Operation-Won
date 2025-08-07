import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';

class AudioService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('operation_won/audio');

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _magicMicEnabled = false;
  Uint8List? _e2eeKey;
  StreamSubscription? _audioStreamSubscription;

  // Opus codec: use opus_dart with opus_flutter
  bool _opusInitialized = false;
  SimpleOpusEncoder? _opusEncoder;
  SimpleOpusDecoder? _opusDecoder;

  // Audio recording stream controller
  final StreamController<Uint8List> _audioDataController =
      StreamController<Uint8List>.broadcast();

  // Error stream controller
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get magicMicEnabled => _magicMicEnabled;
  bool get hasE2EEKey => _e2eeKey != null;
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  Stream<String> get errorStream => _errorController.stream;

  AudioService() {
    _initializeOpus();
    _setupMethodCallHandler();
    // Skip E2EE key generation for now since native implementation is not available
    // _generateE2EEKey();
  }

  Future<void> _initializeOpus() async {
    try {
      initOpus(await opus_flutter.load());
      _opusEncoder = SimpleOpusEncoder(
        sampleRate: 48000,
        channels: 1,
        application: Application.voip,
      );
      _opusDecoder = SimpleOpusDecoder(
        sampleRate: 48000,
        channels: 1,
      );
      _opusInitialized = true;
      debugPrint('[Audio] Opus initialized successfully');
    } catch (e) {
      _errorController.add('Failed to initialize Opus: $e');
      debugPrint('[Audio] Failed to initialize Opus: $e');
      _opusInitialized = false;
    }
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAudioData':
          final audioData = call.arguments as Uint8List;
          final encodedData = await encodeAudioData(audioData);
          if (encodedData != null) {
            _audioDataController.add(encodedData);
          }
          break;
        case 'onRecordingError':
          final error = call.arguments as String;
          _errorController.add('Recording error: $error');
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
      _errorController.add('Failed to request microphone permission: $e');
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
        _errorController.add('Microphone permission denied');
        debugPrint('[Audio] Microphone permission denied');
        return false;
      }

      final result = await _channel.invokeMethod('startRecording');
      _isRecording = result as bool;
      notifyListeners();

      debugPrint('[Audio] Recording started: $_isRecording');
      return _isRecording;
    } catch (e) {
      _errorController.add('Failed to start recording: $e');
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
      _errorController.add('Failed to stop recording: $e');
      debugPrint('[Audio] Failed to stop recording: $e');
    }
  }

  // Play audio chunk
  Future<void> playAudioChunk(Uint8List audioData) async {
    try {
      debugPrint(
          '[Audio] Received encoded audio chunk for playback: ${audioData.length} bytes');
      final decodedData = await decodeAudioData(audioData);
      if (decodedData != null) {
        debugPrint(
            '[Audio] Playing decoded audio chunk: ${decodedData.length} bytes');
        await _channel.invokeMethod('playAudioChunk', decodedData);
      }
    } catch (e) {
      _errorController.add('Failed to play audio chunk: $e');
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
      _errorController.add('Failed to start playing mode: $e');
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
      _errorController.add('Failed to stop playing mode: $e');
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

      debugPrint(
          '[Audio] Audio config set: $sampleRate Hz, $channels ch, $bitRate bps');
    } catch (e) {
      _errorController.add('Failed to set audio config: $e');
      debugPrint('[Audio] Failed to set audio config: $e');
    }
  }

  // Enable/disable Magic Mic (noise suppression and automatic gain control)
  Future<void> setMagicMicEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setMagicMicEnabled', enabled);
      _magicMicEnabled = enabled;
      notifyListeners();

      debugPrint('[Audio] Magic Mic ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _errorController.add('Failed to set Magic Mic: $e');
      debugPrint('[Audio] Failed to set Magic Mic: $e');
    }
  }

  // E2EE Key Management
  Future<void> _generateE2EEKey() async {
    try {
      final keyBytes = await _channel.invokeMethod('generateE2EEKey');
      if (keyBytes != null) {
        _e2eeKey = Uint8List.fromList(keyBytes);
        debugPrint('[Audio] E2EE key generated');
      }
    } catch (e) {
      // Skip error logging for missing plugin implementation
      if (!e.toString().contains('MissingPluginException')) {
        _errorController.add('Failed to generate E2EE key: $e');
        debugPrint('[Audio] Failed to generate E2EE key: $e');
      }
    }
  }

  // Set E2EE key (for sharing between clients)
  Future<bool> setE2EEKey(Uint8List keyBytes) async {
    try {
      final result = await _channel.invokeMethod('setE2EEKey', keyBytes);
      if (result as bool) {
        _e2eeKey = keyBytes;
        debugPrint('[Audio] E2EE key set successfully');
        return true;
      }
      return false;
    } catch (e) {
      _errorController.add('Failed to set E2EE key: $e');
      debugPrint('[Audio] Failed to set E2EE key: $e');
      return false;
    }
  }

  // Get current E2EE key for sharing
  Uint8List? getE2EEKey() {
    return _e2eeKey;
  }

  // Generate new E2EE key
  Future<Uint8List?> generateNewE2EEKey() async {
    await _generateE2EEKey();
    return _e2eeKey;
  }

  // Encode audio data using Opus
  Future<Uint8List?> encodeAudioData(Uint8List audioData) async {
    if (!_opusInitialized) {
      debugPrint('[Audio] Opus not initialized, returning raw audio data');
      return audioData;
    }

    try {
      // Ensure we have the correct amount of data for Opus frame
      const int expectedSamples = 960; // 20ms at 48kHz
      const int bytesPerSample = 2; // 16-bit samples
      const int expectedBytes = expectedSamples * bytesPerSample;

      if (audioData.length != expectedBytes) {
        debugPrint(
            '[Audio] Invalid audio data size: ${audioData.length}, expected: $expectedBytes');
        return audioData; // Return original data if size is wrong
      }

      // Convert Uint8List to Int16List properly
      final ByteData byteData = audioData.buffer.asByteData();
      final Int16List int16Data = Int16List(expectedSamples);

      for (int i = 0; i < expectedSamples; i++) {
        int16Data[i] = byteData.getInt16(i * 2, Endian.little);
      }

      debugPrint('[Audio] Encoding ${int16Data.length} samples');
      final encodedData = _opusEncoder!.encode(input: int16Data);
      debugPrint('[Audio] Encoded to ${encodedData.length} bytes');

      return encodedData;
    } catch (e) {
      _errorController.add('Failed to encode audio data: $e');
      debugPrint('[Audio] Failed to encode audio data: $e');
      return audioData;
    }
  }

  // Decode audio data using Opus
  Future<Uint8List?> decodeAudioData(Uint8List encodedData) async {
    if (!_opusInitialized) {
      debugPrint('[Audio] Opus not initialized, returning raw audio data');
      return encodedData;
    }

    try {
      final decodedInt16 = _opusDecoder!.decode(input: encodedData);

      // Convert Int16List back to Uint8List, explicitly handling endianness
      final Uint8List decodedData = Uint8List(decodedInt16.length * 2);
      final ByteData byteData = decodedData.buffer.asByteData();
      for (int i = 0; i < decodedInt16.length; i++) {
        byteData.setInt16(i * 2, decodedInt16[i], Endian.little);
      }

      return decodedData;
    } catch (e) {
      _errorController.add('Failed to decode audio data: $e');
      debugPrint('[Audio] Failed to decode audio data: $e');
      return encodedData;
    }
  }

  @override
  @override
  void dispose() {
    stopRecording();
    stopPlaying();
    _audioDataController.close();
    _errorController.close();
    _audioStreamSubscription?.cancel();
    _opusEncoder?.destroy();
    _opusDecoder?.destroy();
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
    _errorController.add('Web audio recording not yet implemented');
    return false;
  }

  @override
  Future<void> playAudioChunk(Uint8List audioData) async {
    // Web implementation would use Web Audio API
    _errorController.add('Web audio playback not yet implemented');
  }

  @override
  Future<Uint8List?> encodeAudioData(Uint8List audioData) async {
    // Web implementation would use Opus.js or similar
    _errorController.add('Web audio encoding not yet implemented');
    debugPrint('[Audio] Web audio encoding not yet implemented');
    return audioData; // Return unencoded for now
  }

  @override
  Future<Uint8List?> decodeAudioData(Uint8List encodedData) async {
    // Web implementation would use Opus.js or similar
    _errorController.add('Web audio decoding not yet implemented');
    debugPrint('[Audio] Web audio decoding not yet implemented');
    return encodedData; // Return as-is for now
  }
}
