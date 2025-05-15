# Operation Won PoC Client

A simple Flutter proof-of-concept (PoC) client implementation for the Operation Won project that demonstrates push-to-talk functionality over WebSockets.

## Features

- WebSocket connection to the PoC server
- Push-to-talk (PTT) audio transmission
- Audio playback for received messages
- Audio replay functionality

## How It Works

1. **Connect to Server**: Establishes WebSocket connection to the PoC server
2. **Push-to-Talk**: 
   - Press and hold the PTT button to record and stream audio
   - Release to stop recording and send a stop signal
3. **Audio Reception**:
   - Automatically plays audio received from other connected clients
4. **Audio Replay**:
   - Fetches and plays the latest audio recording from the server

## Technical Details

- Uses websocket_channel for real-time communication
- Uses record for audio capture
- Uses just_audio for audio playback
- Handles binary messages for audio data and text messages for control signals

## Running the App

Ensure the server is running, then:

```
flutter run
```

## Server Configuration

By default, the app connects to `ws://10.0.2.2:8080` for Android emulators, which maps to the host machine's localhost. For physical devices or different environments, change the `serverAddress` variable in `home_screen.dart`.

## Dependencies

- web_socket_channel
- record
- just_audio
- permission_handler
- http
