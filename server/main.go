package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Upgrader for WebSocket connections with permissive CORS policy for easy testing
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// MessagePayload represents a message to be broadcast to clients
type MessagePayload struct {
	Data   []byte
	Sender *Client
}

// Client represents a connected websocket client
type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
	file *os.File // Current audio file being written to
}

// Hub maintains the set of active clients and broadcasts messages
type Hub struct {
	clients    map[*Client]bool
	broadcast  chan MessagePayload
	register   chan *Client
	unregister chan *Client
	mu         sync.Mutex
}

// Create a new hub instance
func newHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan MessagePayload),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

// Run the hub's main loop for handling messages and client connections
func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Println("New client connected")

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				if client.file != nil {
					client.file.Close()
				}
			}
			h.mu.Unlock()
			log.Println("Client disconnected")

		case message := <-h.broadcast:
			h.mu.Lock()
			for client := range h.clients {
				if client != message.Sender {
					select {
					case client.send <- message.Data:
					default:
						close(client.send)
						delete(h.clients, client)
						if client.file != nil {
							client.file.Close()
						}
					}
				}
			}
			h.mu.Unlock()
		}
	}
}

// Read messages from the websocket connection
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(32768) // Max message size: 32KB
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		messageType, messageData, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		// Handle the message based on its type
		if messageType == websocket.BinaryMessage {
			// Binary message: audio data
			// Open the file for writing if not already open
			if c.file == nil {
				c.file, err = os.OpenFile("poc_audio.opus", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
				if err != nil {
					log.Printf("Error opening audio file: %v", err)
					continue
				}
			}

			// Append the audio data to the file
			_, err = c.file.Write(messageData)
			if err != nil {
				log.Printf("Error writing to audio file: %v", err)
			}

			// Broadcast the audio data to other clients
			c.hub.broadcast <- MessagePayload{Data: messageData, Sender: c}

		} else if messageType == websocket.TextMessage {
			// Text message: control signal (JSON)
			var controlMsg struct {
				Type string `json:"type"`
			}

			if err := json.Unmarshal(messageData, &controlMsg); err != nil {
				log.Printf("Error parsing control message: %v", err)
				continue
			}

			if controlMsg.Type == "ptt_stop" {
				// Close the audio file when PTT is released
				if c.file != nil {
					c.file.Close()
					c.file = nil
					log.Println("PTT released, audio file closed")
				}
			}
		}
	}
}

// Write messages to the websocket connection
func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second) // Send pings at regular intervals
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				// The hub closed the channel
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.BinaryMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued messages to the current websocket message
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// Handler for WebSocket connections
func serveWsHandler(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Error upgrading to WebSocket:", err)
		return
	}

	client := &Client{
		hub:  hub,
		conn: conn,
		send: make(chan []byte, 256),
	}

	client.hub.register <- client

	// Start the client's read and write pump goroutines
	go client.writePump()
	go client.readPump()
}

// Handler for audio replay requests
func replayAudioHandler(w http.ResponseWriter, r *http.Request) {
	// For the PoC, we'll just serve the raw binary data
	// In a real application, we would properly format the audio for client compatibility
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, "poc_audio.opus")
}

func main() {
	log.Println("Starting PoC Server...")

	// Create and run the hub
	hub := newHub()
	go hub.run()

	// Register HTTP handlers
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWsHandler(hub, w, r)
	})
	http.HandleFunc("/replay", replayAudioHandler)

	// Start the server
	log.Fatal(http.ListenAndServe(":8080", nil))
}
