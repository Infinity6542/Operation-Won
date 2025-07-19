// hub.go - WebSocket hub implementation for managing client connections and message broadcasting
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

// * Structs
type Client struct {
	ID                string
	UserID            int
	ChannelID         string
	hub               *Hub
	conn              *websocket.Conn
	send              chan []byte
	isRecording       bool
	currentMessageeID string
}

type Message struct {
	ChannelID string
	Data      []byte
	Sender    *Client
}

type ChannelChangeRequest struct {
	Client       *Client
	NewChannelID string
}

type Signal struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type Hub struct {
	channels      map[string]map[*Client]bool
	broadcast     chan *Message
	register      chan *Client
	unregister    chan *Client
	changeChannel chan *ChannelChangeRequest
	mu            sync.Mutex
	redis         *redis.Client
}

type ChannelChange struct {
	Client       *Client
	NewChannelID string
}

func NewHub(redis *redis.Client) *Hub {
	return &Hub{
		channels:      make(map[string]map[*Client]bool),
		broadcast:     make(chan *Message),
		register:      make(chan *Client),
		unregister:    make(chan *Client),
		changeChannel: make(chan *ChannelChangeRequest),
		redis:         redis,
	}
}

func (h *Hub) Start() {
	log.Println("[HUB] [INI] Starting the hub.")
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
			log.Printf("[HUB] [CNT] Client registers to channel %s.", client.ChannelID)
		case client := <-h.unregister:
			h.unregisterClient(client)
		case message := <-h.broadcast:
			h.broadcastMsg(message)
		case req := <-h.changeChannel:
			h.switchChannel(req)
		}
	}
}

func (h *Hub) unregisterClient(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	ctx := context.Background()

	if room, ok := h.channels[c.ChannelID]; ok {
		if _, ok := room[c]; ok {
			if c.isRecording {
				speakerLockKey := fmt.Sprintf("channel:%s:speaker", c.ChannelID)
				h.redis.Del(ctx, speakerLockKey)
				log.Printf("[HUB] [USR] Speaker lock for channel %s has been released due to unregistration", c.ChannelID)
			}
			delete(room, c)
			close(c.send)
			if len(room) == 0 {
				delete(h.channels, c.ChannelID)
				log.Printf("[HUB] [CHN] Channel %s is empty and closed", c.ChannelID)
			}
		}
	}
	log.Printf("[HUB] [USR] User %s has been unreigstered from channel %s", c.ID, c.ChannelID)
}

func (h *Hub) broadcastMsg(message *Message) {
	h.mu.Lock()
	channelClients := h.channels[message.ChannelID]
	h.mu.Unlock()

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

func (h *Hub) switchChannel(req *ChannelChangeRequest) {
	h.mu.Lock()
	defer h.mu.Unlock()

	oldChannelID := req.Client.ChannelID

	if oldRoom, ok := h.channels[req.Client.ChannelID]; ok {
		delete(oldRoom, req.Client)
		if len(oldRoom) == 0 {
			delete(h.channels, req.Client.ChannelID)
		}
	}

	req.Client.ChannelID = req.NewChannelID
	if _, ok := h.channels[req.NewChannelID]; !ok {
		h.channels[req.NewChannelID] = make(map[*Client]bool)
	}
	h.channels[req.NewChannelID][req.Client] = true
	log.Printf("[HUB] [CHN] [MVE] User %s moved from channel %s to %s", req.Client.ID, oldChannelID, req.NewChannelID)
}

// * WS handling
const (
	maxMessageSize  = 4096 // This should be editable sometime later (requires reload?)
	pongWait        = 30 * time.Second
	pingInterval    = pongWait * 9 / 10
	waitOnReceiving = 10 * time.Second
)

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPingHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
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

				msg := &Message{ChannelID: c.ChannelID, Data: messageData, Sender: c}
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
		case msg, ok := <-c.send:
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
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(waitOnReceiving))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				log.Printf("[WBS] [PNG] Something went wrong with the client: %s", err)
				return
			}
		}
	}
}
