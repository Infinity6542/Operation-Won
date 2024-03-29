// ignore_for_file: no_leading_underscores_for_local_identifiers, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';
// import 'main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'dart:developer' as dev;

const String appId = "b362bf39ccfe4705bca1e5cf4c7ff960";
Timer? timer;

//TODO: Remove title requirement from Home once app is complete

// Agora Engine
String channelName = "";
String token = "";
int uid = 0; // uid of the local user
int? _remoteUid; // uid of the remote user
bool _isJoined = false; // Indicates if the local user has joined the channel
late RtcEngine agoraEngine; // Agora engine instance
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(); // Global key to access the scaffold
int tokenRole = 1; // use 1 for Host/Broadcaster, 2 for Subscriber/Audience
String serverUrl =
    "https://agora-token-server-2g0m.onrender.com"; // The base URL to your token server, for example "https://agora-token-service-production-92ff.up.railway.app"
int tokenExpireTime = 86400; // Expire time in Seconds.
bool isTokenExpiring = false; // Set to true when the token is about to expire
final channelTextController =
    TextEditingController(text: ''); // To access the TextField
bool _isMuted = false;
int volume = 50;

class Master extends StatefulWidget {
  static const String id = "/Master";
  const Master({super.key});

  @override
  State<Master> createState() => MasterState();
}

class MasterState extends State<Master> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

class AudioHandler extends BaseAudioHandler {
  final MasterState handler = MasterState();
  @override
  Future<void> play() async {
    _isMuted = false;
    agoraEngine.muteAllRemoteAudioStreams(_isMuted);
    dev.log('[LOG] [AUDIO] Unmuted user');
  }

  @override
  Future<void> pause() async {
    _isMuted = true;
    agoraEngine.muteAllRemoteAudioStreams(_isMuted);
    dev.log('[LOG] [AUDIO] Muted user');
  }

  @override
  Future<void> stop() async {
    _isMuted = false;
    agoraEngine.muteAllRemoteAudioStreams(_isMuted);
    dev.log('[LOG] [AUDIO] User stopped media');
  }
}

class Home extends StatefulWidget {
  static const String id = "/Home";
  const Home({super.key, required this.title});

  final title;

  @override
  State<Home> createState() => _HomeState();
}

// TODO: Figure out what to make this look like
// TODO: Figure out how this is going to work

class _HomeState extends State<Home> {
  testMuteStatus() {
    return _isMuted;
  }

  Future<void> setupVoiceSDKEngine() async {
    // retrieve or request microphone permission
    await [Permission.microphone].request();

    //create an instance of the Agora engine
    agoraEngine = createAgoraRtcEngine();
    await agoraEngine.initialize(const RtcEngineContext(appId: appId));

    // Register the event handler
    agoraEngine.registerEventHandler(
      RtcEngineEventHandler(
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          showMessage('Token expiring');
          isTokenExpiring = true;
          setState(() {
            // fetch a new token when the current token is about to expire
            fetchToken(uid, channelName, tokenRole);
          });
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage(
              "Successfully joined ${connection.channelId}. Your uid is ${connection.localUid}");
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          showMessage("User uid:$remoteUid joined ${connection.channelId}");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Set up an instance of Agora engine
    createAgoraRtcEngine();
    setupVoiceSDKEngine();
    timer = Timer.periodic(
        const Duration(seconds: 5), (Timer t) => testMuteStatus());
  }

  // Fetch the call token :)
  Future<void> fetchToken(int uid, String channelName, int tokenRole) async {
    // Prepare the Url
    String url =
        '$serverUrl/rtc/$channelName/${tokenRole.toString()}/uid/${uid.toString()}?expiry=${tokenExpireTime.toString()}';

    // Send the request
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // If the server returns an OK response, then parse the JSON.
      Map<String, dynamic> json = jsonDecode(response.body);
      String newToken = json['rtcToken'];
      debugPrint('Token Received: $newToken');
      // Use the token to join a channel or renew an expiring token
      setToken(newToken);
    } else {
      // If the server did not return an OK response,
      // then throw an exception.
      throw Exception(
          'Failed to fetch a token. Make sure that your server URL is valid');
    }
  }

  // Use the token to join or renew the token
  void setToken(String newToken) async {
    // Set channel options including the client role and channel profile
    ChannelMediaOptions options = const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    );
    token = newToken;

    if (isTokenExpiring) {
      // Renew the token
      agoraEngine.renewToken(token);
      isTokenExpiring = false;
      showMessage("Token renewed");
    } else {
      // Join a channel.
      showMessage("Token received, joining a channel...");

      await agoraEngine.joinChannel(
        token: token,
        channelId: channelName,
        options: options,
        uid: uid,
      );
    }
  }

  void join() async {
    setupVoiceSDKEngine();
    channelName = channelTextController.text;
    if (channelName.isEmpty) {
      showMessage("Enter a channel name");
      return;
    } else {
      showMessage("Fetching a token from the server...");
    }

    await fetchToken(uid, channelName, tokenRole);
  }

  void leave() {
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
    agoraEngine.leaveChannel();
    agoraEngine.release();
  }

  onMuteChecked(bool value) {
    setState(() {
      _isMuted = value;
      agoraEngine.muteAllRemoteAudioStreams(_isMuted);
    });
  }

  onVolumeChanged(double newValue) {
    setState(() {
      volume = newValue.toInt();
      agoraEngine.adjustRecordingSignalVolume(volume);
    });
  }

// Clean up the resources when the user leaves
  @override
  void dispose() async {
    await agoraEngine.leaveChannel();
    await agoraEngine.release();
    timer?.cancel();
    super.dispose();
  }

  showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(190),
          child: AppBar(
            title: Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'ABCSANS',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage('assets/header.png'), fit: BoxFit.fill),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [
            // Channel name input
            TextField(
              controller: channelTextController,
              decoration:
                  const InputDecoration(hintText: 'Type the channel name here'),
            ),
            // Status text
            SizedBox(height: 40, child: Center(child: _status())),
            Row(
              children: <Widget>[
                Checkbox(
                    value: _isMuted,
                    onChanged: (_isMuted) => {onMuteChecked(_isMuted!)}),
                const Text("Mute"),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: volume.toDouble(),
                    onChanged: (value) => {onVolumeChanged(value)},
                  ),
                ),
              ],
            ),
            // Button Row
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    child: const Text("Join"),
                    onPressed: () => {join()},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    child: const Text("Leave"),
                    onPressed: () => {leave()},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _status() {
    String statusText;

    if (!_isJoined) {
      statusText = 'Join a channel';
    } else if (_remoteUid == null)
      statusText = 'Waiting for a remote user to join...';
    else
      statusText = 'Connected to remote user, uid:$_remoteUid';

    return Text(
      statusText,
    );
  }
}
