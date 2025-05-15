import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeScreenFullySimplified extends StatefulWidget {
  const HomeScreenFullySimplified({Key? key}) : super(key: key);

  @override
  HomeScreenFullySimplifiedState createState() =>
      HomeScreenFullySimplifiedState();
}

class HomeScreenFullySimplifiedState extends State<HomeScreenFullySimplified> {
  // Server configuration
  final String serverAddress =
      'ws://10.0.2.2:8080'; // Use this for Android emulator
  // final String serverAddress = 'ws://localhost:8080'; // Use this for web testing

  // Connection states
  bool isConnected = false;
  bool isConnecting = false;
  String connectionStatus = 'Disconnected';

  // Audio states
  bool isRecording = false;
  bool isReceivingAudio = false;
  bool isReplayingAudio = false;
  String audioStatus = '';

  // WebSocket connection
  WebSocketChannel? webSocketChannel;

  // Audio playback (only for user feedback, not actually used)
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _disconnectFromServer();
    _player.dispose();
    super.dispose();
  }

  // Request microphone permissions
  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showSnackBar('Microphone permission is required for PTT functionality');
    }
  }

  // Connect to the WebSocket server
  Future<void> _connectToServer() async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      final wsUrl = Uri.parse('$serverAddress/ws');
      webSocketChannel = WebSocketChannel.connect(wsUrl);

      // Listen for incoming messages
      webSocketChannel!.stream.listen(
        (dynamic data) {
          // Handle binary audio data received from other clients
          if (data is List<int>) {
            _handleIncomingAudio(Uint8List.fromList(data));
          }
          // Handle text messages (could be status updates or other control messages)
          else if (data is String) {
            try {
              final jsonData = jsonDecode(data);
              print('Received JSON: $jsonData');
              // Handle any control messages here
            } catch (e) {
              print('Received text (not JSON): $data');
            }
          }
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
      );

      setState(() {
        isConnected = true;
        isConnecting = false;
        connectionStatus = 'Connected';
      });

      _showSnackBar('Connected to server');
    } catch (e) {
      setState(() {
        isConnecting = false;
        connectionStatus = 'Connection failed';
      });
      _showSnackBar('Failed to connect: $e');
      print('Connection error: $e');
    }
  }

  // Disconnect from the WebSocket server
  void _disconnectFromServer() {
    if (webSocketChannel != null) {
      webSocketChannel!.sink.close();
      webSocketChannel = null;
    }

    setState(() {
      isConnected = false;
      connectionStatus = 'Disconnected';
    });
  }

  // Handle server disconnect
  void _handleDisconnect() {
    setState(() {
      isConnected = false;
      connectionStatus = 'Disconnected';
      webSocketChannel = null;
    });
  }

  // Handle PTT button press - simulate recording
  Future<void> _onPushToTalkPressed() async {
    if (!isConnected) {
      _showSnackBar('Connect to server first');
      return;
    }

    // Instead of actually recording, we'll just simulate it for the PoC
    setState(() {
      isRecording = true;
      audioStatus = 'Recording... (Simulated)';
    });

    _showSnackBar('PTT active - Simulated recording');
  }

  // Handle PTT button release - send simulated audio
  Future<void> _onPushToTalkReleased() async {
    if (isRecording) {
      setState(() {
        isRecording = false;
        audioStatus = 'Sending audio... (Simulated)';
      });

      if (webSocketChannel != null) {
        // Send simulated audio data (just a dummy byte array)
        final dummyAudio =
            Uint8List.fromList(List.generate(1000, (i) => i % 255));
        webSocketChannel!.sink.add(dummyAudio);

        // Send PTT stop signal
        webSocketChannel!.sink.add(jsonEncode({'type': 'ptt_stop'}));

        setState(() {
          audioStatus = '';
        });
      }
    }
  }

  // Handle incoming audio data from other clients
  Future<void> _handleIncomingAudio(Uint8List audioData) async {
    if (isRecording) return; // Don't play incoming audio while recording

    // For the PoC, we'll just simulate playing the audio
    setState(() {
      isReceivingAudio = true;
      audioStatus = 'Receiving live audio... (${audioData.length} bytes)';
    });

    // Simulate audio playback for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        isReceivingAudio = false;
        if (!isRecording && !isReplayingAudio) {
          audioStatus = '';
        }
      });
    }
  }

  // Fetch and play the latest audio recording from the server
  Future<void> _getAndPlayLastRecording() async {
    if (!isConnected) {
      _showSnackBar('Connect to server first');
      return;
    }

    setState(() {
      isReplayingAudio = true;
      audioStatus = 'Fetching replay...';
    });

    try {
      // Get the URL by removing 'ws://' and replacing with 'http://'
      final replayUrl =
          Uri.parse(serverAddress.replaceAll('ws://', 'http://') + '/replay');

      final response = await http.get(replayUrl);

      if (response.statusCode == 200) {
        setState(() {
          audioStatus =
              'Playing replay... (${response.bodyBytes.length} bytes)';
        });

        // Simulate audio playback for 3 seconds
        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          setState(() {
            isReplayingAudio = false;
            audioStatus = '';
          });
        }
      } else {
        _showSnackBar('Failed to fetch replay: ${response.statusCode}');
        setState(() {
          isReplayingAudio = false;
          audioStatus = '';
        });
      }
    } catch (e) {
      _showSnackBar('Error fetching replay: $e');
      setState(() {
        isReplayingAudio = false;
        audioStatus = '';
      });
      print('Replay error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operation Won PoC - Simplified'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Connection status
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color:
                      isConnected ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Status: $connectionStatus',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isConnected
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Audio status
              if (audioStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRecording
                            ? Icons.mic
                            : (isReceivingAudio || isReplayingAudio
                                ? Icons.volume_up
                                : Icons.info),
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        audioStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32.0),

              // Connect/Disconnect Button
              ElevatedButton(
                onPressed: isConnecting
                    ? null
                    : (isConnected ? _disconnectFromServer : _connectToServer),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(isConnecting
                    ? 'Connecting...'
                    : (isConnected ? 'Disconnect' : 'Connect to Server')),
              ),

              const SizedBox(height: 16.0),

              // Push-to-Talk Button
              GestureDetector(
                onTapDown: (_) => _onPushToTalkPressed(),
                onTapUp: (_) => _onPushToTalkReleased(),
                onTapCancel: () => _onPushToTalkReleased(),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isRecording ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Push to Talk (Simulated)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16.0),

              // Replay Button
              ElevatedButton(
                onPressed: isConnected && !isReplayingAudio
                    ? _getAndPlayLastRecording
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Get Last Message & Replay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
