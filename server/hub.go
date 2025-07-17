// TODO: use log instead of fmt when logging
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// * Structs
type Client struct {
	ID        string
	UserID    int
	ChannelID string
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
	isRecording bool
	currentMessageeID string
}

type Message struct {
	ChannelID string
	Data      []byte
	Sender    *Client
}

type Signal struct {
	Type string `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type Hub struct {
	channels   map[string]map[*Client]bool
	broadcast  chan *Message
	register   chan *Client
	unregister chan *Client
	mu         sync.Mutex
}

func NewHub() *Hub {
	return &Hub{
		channels:   make(map[string]map[*Client]bool),
		broadcast:  make(chan *Message),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h* Hub) Start() {
	fmt.Println("[HUB] [INI] Starting the hub.")
	// There's probably a better way to do this... Perhaps this is what goroutines are for, will look into it
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if _, ok := h.channels[client.ChannelID]; !ok {
				h.channels[client.ChannelID] = make(map[*Client]bool)
			}
			h.channels[client.ChannelID][client] = true
			h.mu.Unlock()
			fmt.Printf("\n[HUB] [CNT] Client registeres to channel %s.", client.ChannelID)
		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.channels[client.ChannelID]; !ok {
				delete(h.channels[client.ChannelID], client)
				close(client.send)
				if len(h.channels[client.ChannelID]) == 0 {
					delete(h.channels, client.ChannelID)
				}
			}
			h.mu.Unlock()
			fmt.Printf("\n[HUB] [LVE] Client left channel %s", client.ChannelID)
		case message := <-h.broadcast:
			h.mu.Lock()
			channelClients := h.channels[message.ChannelID]
			for client := range channelClients {
				if client != message.Sender {
					select {
					case client.send <- message.Data:
					default:
						close(client.send)
						delete(channelClients, client)
					}
				}
			}
		}
	}
}

//* WS handling
const (
	maxMessageSize = 4096 // This should be editable sometime later (requires reload?)
	pongWait = 30*time.Second
	pingInterval = pongWait*9/10
	waitOnReceiving = 10*time.Second
)

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPingHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait));
		return nil
	})

	for {
		messageType, messageData, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WBS] [CLI] Client unexpectedly closed the connection: %v", err)
			} else {
				log.Printf("[WBS] [RED] Something went wrong while reading the WebSocket message: %v", err)
			}
			break
		}
		switch messageType {
		case websocket.TextMessage:
			var s Signal
			if err := json.Unmarshal(messageData, &s); err != nil {
				log.Printf("[WBS] [MSG] Inavlid message from client %s: %v", c.ID, err)
				continue
			}
			c.handleSignal(s)
		case websocket.BinaryMessage:
			if c.isRecording {
				file := fmt.Sprintf("./audio/%s.opus", c.currentMessageeID)
				f, err := os.OpenFile(file, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0600)
				if err != nil {
					log.Printf("[REC] [OPN] Failed to open file %s: $%v", file, err)
					continue
				}
				if _, err := f.Write(messageData); err != nil {
					log.Printf("[REC] [WRT] Failed to write to file %s: %v", file, err)
					continue
				}
				f.Close()

				msg := &Message{ChannelID:c.ChannelID,Data:messageData,Sender:c}
				c.hub.broadcast <- msg
			}
		}
	}
}

func (c *Client) handleSignal(s Signal) {
	switch s.Type {
	case "ptt start":
	case "ptt stop":
	default:
		log.Printf("[WBS] [SIG] Received unknown signal from client '%s', consider updating the server.", s.Type)
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingInterval)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <- c.send:
		c.conn.SetWriteDeadline(time.Now().Add(waitOnReceiving))
		if !ok {
			log.Println("[WBS] [WRT] Something went wrong!")
			c.conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}
		w, err := c.conn.NextWriter(websocket.BinaryMessage)
		if err != nil {
			log.Printf("[WBS] [WRT] Something went wrong while preparing the writer: %s", err)
			return
		}
		w.Write(msg)
		n := len(c.send)
		for i := 0; i < n; i++ {
			w.Write(<-c.send)
		}
		if err := w.Close(); err != nil {
			log.Printf("[WBS] [CLS] Something went wrong while closing the WebSocket connection: %s", err)
			return
		}
	case <- ticker.C:
		c.conn.SetWriteDeadline(time.Now().Add(waitOnReceiving))
		if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
			log.Printf("[WBS] [PNG] Something went wrong with the client: %s", err)
			return
		}
		}
	}
}

func ServeWs (hub *Hub, w http.ResponseWriter, r *http.Request) {
	channelID := r.URL.Query().Get("channel")
	if channelID == "" {
		http.Error(w, "Invalid Channel ID.", http.StatusBadRequest)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WBS] [UPG] Error while upgrading HTTP to WebSockets: %s", err)
	}

	client := &Client {
		ID: uuid.New().String(),
		hub: hub,
		conn: conn,
		send: make(chan []byte, 256),
		ChannelID: channelID,
	}

	hub.register <- client
	go client.writePump()
	go client.readPump()
}
