import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'services/communication_service.dart';
import 'providers/settings_provider.dart';

@NowaGenerated()
class CommsState extends ChangeNotifier {
  CommunicationService? _communicationService;
  String? _currentChannelId;
  bool _isInitialized = false;

  CommsState();

  factory CommsState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<CommsState>(context, listen: listen);
  }

  // Communication status getters
  bool get isConnected => _communicationService?.isConnected ?? false;
  bool get isPTTActive => _communicationService?.isPTTActive ?? false;
  bool get isRecording => _communicationService?.isRecording ?? false;
  bool get isPTTToggleMode => _communicationService?.isPTTToggleMode ?? false;
  bool get isEmergencyMode => _communicationService?.isEmergencyMode ?? false;
  bool get isMagicMicEnabled =>
      _communicationService?.isMagicMicEnabled ?? false;
  bool get hasE2EEKey => _communicationService?.hasE2EEKey ?? false;
  String? get currentChannelId => _currentChannelId;
  bool get isInitialized => _isInitialized;

  // Initialize communication service with settings provider
  void initialize(SettingsProvider settingsProvider) {
    if (_isInitialized) return;

    _communicationService = CommunicationService(settingsProvider);
    _communicationService!.addListener(() {
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();

    debugPrint('[CommsState] Communication service initialized');
  }

  // Connect to WebSocket
  Future<bool> connectToServer() async {
    if (_communicationService == null) return false;
    return await _communicationService!.connectWebSocket();
  }

  // Disconnect from WebSocket
  Future<void> disconnectFromServer() async {
    if (_communicationService == null) return;
    await _communicationService!.disconnectWebSocket();
  }

  // Join a channel
  Future<void> joinChannel(String channelId) async {
    if (_communicationService == null) return;

    await _communicationService!.joinChannel(channelId);
    _currentChannelId = channelId;
    notifyListeners();
  }

  // Leave current channel
  Future<void> leaveChannel() async {
    if (_communicationService == null) return;

    await _communicationService!.leaveChannel();
    _currentChannelId = null;
    notifyListeners();
  }

  // Start Push-to-Talk
  Future<bool> startPTT() async {
    if (_communicationService == null) return false;
    return await _communicationService!.startPTT();
  }

  // Stop Push-to-Talk
  Future<void> stopPTT() async {
    if (_communicationService == null) return;
    await _communicationService!.stopPTT();
  }

  // Test connection
  Future<bool> testConnection() async {
    if (_communicationService == null) return false;
    return await _communicationService!.testConnection();
  }

  // Check microphone permission
  Future<bool> checkMicrophonePermission() async {
    if (_communicationService == null) return false;
    return await _communicationService!.checkMicrophonePermission();
  }

  // Join emergency channel
  Future<void> joinEmergencyChannel() async {
    if (_communicationService == null) return;
    await _communicationService!.joinEmergencyChannel();
    notifyListeners();
  }

  // Exit emergency mode and return to previous channel
  Future<void> exitEmergencyMode() async {
    if (_communicationService == null) return;
    await _communicationService!.exitEmergencyMode();
  }

  // E2EE Key Management
  Future<Uint8List?> generateE2EEKey() async {
    if (_communicationService == null) return null;
    return await _communicationService!.generateE2EEKey();
  }

  Future<bool> setE2EEKey(Uint8List keyBytes) async {
    if (_communicationService == null) return false;
    return await _communicationService!.setE2EEKey(keyBytes);
  }

  Uint8List? getE2EEKey() {
    if (_communicationService == null) return null;
    return _communicationService!.getE2EEKey();
  }

  // Legacy methods for compatibility
  void createEvent() {
    // This is handled by EventProvider now
    debugPrint('[CommsState] createEvent called - handled by EventProvider');
  }

  void createChannel() {
    // This is handled by ChannelProvider now
    debugPrint(
        '[CommsState] createChannel called - handled by ChannelProvider');
  }

  void getChannels() {
    // This is handled by ChannelProvider now
    debugPrint('[CommsState] getChannels called - handled by ChannelProvider');
  }

  void getEvents() {
    // This is handled by EventProvider now
    debugPrint('[CommsState] getEvents called - handled by EventProvider');
  }

  @override
  void dispose() {
    _communicationService?.removeListener(() {});
    _communicationService?.dispose();
    super.dispose();
  }
}
