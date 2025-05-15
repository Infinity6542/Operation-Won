# Operation Won PoC Server

This is a simple proof of concept (PoC) WebSocket server for push-to-talk audio communication.

## Features

- WebSocket server for real-time audio streaming
- Push-to-talk (PTT) functionality
- Audio storage and replay
- Minimal implementation focusing on core functionality

## How It Works

1. Client connects to the WebSocket server at `/ws`
2. Client sends audio data as binary WebSocket messages when PTT is active
3. Server broadcasts audio to all other connected clients
4. Client sends a JSON message `{"type": "ptt_stop"}` when PTT button is released
5. Audio is stored in a single file (`poc_audio.opus`)
6. Clients can request the latest audio file for replay at `/replay`

## API

### WebSocket Connection

- Connect to `ws://localhost:8080/ws`

### Message Types

- **Binary Messages**: Audio data chunks
- **Text Messages**: Control signals in JSON format, e.g., `{"type": "ptt_stop"}`

### HTTP Endpoints

- `GET /replay`: Returns the latest audio file

## Running the Server

```
go run main.go
```

The server will listen on port 8080.

## Dependencies

- gorilla/websocket: WebSocket library
- Standard Go libraries: encoding/json, log, net/http, os, sync
