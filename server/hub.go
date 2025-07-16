// TODO: use log instead of fmt when logging
package main

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"
	"log"
	"github.com/gorilla/websocket"
)

// * Structs
type Client struct {
	ID        int
	UserID    int
	ChannelID string
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
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
			//TODO: Handle this
		case websocket.BinaryMessage:
			//TODO: Handle this
		}
	}
}

func (c *Client) handleSignal(s Signal) {
	switch sig.Type {
	case "ptt start":
	}
}
