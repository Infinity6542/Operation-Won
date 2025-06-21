package main

import (
	// "encoding/json"
	"log"
	// "net/http"
	// "os"
	// "sync"
	// "time"
	// "github.com/gorilla/websocket"
)

// Ok so I need to rewrite this entire thing basically
// After I finish the server I can start on the client
// But first the server and the design

// Please refer to the flowcharts to know what to name these things cos otherwise I will forget lol :)

// When will this thing refresh smh I need to get it now

// Upgrader for WebSocket connections with permissive CORS policy for easy testing

// 1. Make sure all services are running first (redis, DB, HTTP server) JSON signals as well
// 2. Wait for connection
// 3. Once connections are made, listen for messages (messages go through router)
// 4. If there is a new transmission, made new UUID, new file, new record and alert recipients
// 5. Run reading, writing and broadcasting (to UUID.e and distribute to clients)

func main() {
	log.Println("Starting up...")
}
