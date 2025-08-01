// WebSocket hub implementation for managing client connections and message broadcasting
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

// Structs
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

			// Add user to Redis channel set and update session
			ctx := context.Background()
			h.redis.SAdd(ctx, fmt.Sprintf("channel:%s:users", client.ChannelID), client.UserID)
			h.redis.Set(ctx, fmt.Sprintf("user:%d:session", client.UserID), client.ID, 30*time.Minute)
			h.redis.Set(ctx, fmt.Sprintf("user:%d:channel", client.UserID), client.ChannelID, 30*time.Minute)

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
				// Only release lock if this client owns it
				currentSpeaker := h.redis.Get(ctx, speakerLockKey).Val()
				if currentSpeaker == fmt.Sprintf("%d", c.UserID) {
					h.redis.Del(ctx, speakerLockKey)
					log.Printf("[HUB] [USR] Speaker lock for channel %s has been released due to unregistration", c.ChannelID)
				}
			}

			// Remove from local channel map
			delete(room, c)
			close(c.send)

			// Clean up Redis data
			h.redis.SRem(ctx, fmt.Sprintf("channel:%s:users", c.ChannelID), c.UserID)
			h.redis.Del(ctx, fmt.Sprintf("user:%d:session", c.UserID))
			h.redis.Del(ctx, fmt.Sprintf("user:%d:channel", c.UserID))

			if len(room) == 0 {
				delete(h.channels, c.ChannelID)
				// Clean up empty channel data from Redis
				h.redis.Del(ctx, fmt.Sprintf("channel:%s:users", c.ChannelID))
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

	ctx := context.Background()
	oldChannelID := req.Client.ChannelID

	// Remove from old channel
	if oldRoom, ok := h.channels[req.Client.ChannelID]; ok {
		delete(oldRoom, req.Client)

		// Update Redis - remove from old channel
		h.redis.SRem(ctx, fmt.Sprintf("channel:%s:users", oldChannelID), req.Client.UserID)

		if len(oldRoom) == 0 {
			delete(h.channels, req.Client.ChannelID)
			// Clean up empty channel data from Redis
			h.redis.Del(ctx, fmt.Sprintf("channel:%s:users", oldChannelID))
		}
	}

	// Add to new channel
	req.Client.ChannelID = req.NewChannelID
	if _, ok := h.channels[req.NewChannelID]; !ok {
		h.channels[req.NewChannelID] = make(map[*Client]bool)
	}
	h.channels[req.NewChannelID][req.Client] = true

	// Update Redis - add to new channel
	h.redis.SAdd(ctx, fmt.Sprintf("channel:%s:users", req.NewChannelID), req.Client.UserID)
	h.redis.Set(ctx, fmt.Sprintf("user:%d:channel", req.Client.UserID), req.NewChannelID, 30*time.Minute)

	log.Printf("[HUB] [CHN] [MVE] User %s moved from channel %s to %s", req.Client.ID, oldChannelID, req.NewChannelID)
}

// WebSocket handling constants
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
		messageType, messageData, e := c.conn.ReadMessage()
		if e != nil {
			if websocket.IsUnexpectedCloseError(e, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WBS] [CLI] Client unexpectedly closed the connection: %v", e)
			} else {
				log.Printf("[WBS] [RED] Something went wrong while reading the WebSocket message: %v", e)
			}
			break
		}
		switch messageType {
		case websocket.TextMessage:
			var s Signal
			if e := json.Unmarshal(messageData, &s); e != nil {
				log.Printf("[WBS] [MSG] Inavlid message from client %s: %v", c.ID, e)
				continue
			}
			c.handleSignal(s)
		case websocket.BinaryMessage:
			if c.isRecording {
				file := fmt.Sprintf("./audio/%s.opus", c.currentMessageeID)
				f, e := os.OpenFile(file, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0600)
				if e != nil {
					log.Printf("[REC] [OPN] Failed to open file %s: $%v", file, e)
					continue
				}
				if _, e := f.Write(messageData); e != nil {
					log.Printf("[REC] [WRT] Failed to write to file %s: %v", file, e)
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
	ctx := context.Background()

	switch s.Type {
	case "ptt start":
		speakerLockKey := fmt.Sprintf("channel:%s:speaker", c.ChannelID)

		// Try to acquire speaker lock with 30 second expiration
		acquired := c.hub.redis.SetNX(ctx, speakerLockKey, c.UserID, 30*time.Second).Val()

		if acquired {
			c.isRecording = true
			c.currentMessageeID = fmt.Sprintf("%d-%d", c.UserID, time.Now().Unix())

			log.Printf("[HUB] [PTT] User %d acquired speaker lock for channel %s", c.UserID, c.ChannelID)

			// Notify other clients in the channel that someone is speaking
			speakerNotification := map[string]interface{}{
				"type":       "speaker_active",
				"user_id":    c.UserID,
				"channel_id": c.ChannelID,
			}

			if notificationData, e := json.Marshal(speakerNotification); e == nil {
				message := &Message{
					ChannelID: c.ChannelID,
					Data:      notificationData,
					Sender:    c,
				}
				c.hub.broadcast <- message
			}

			// Send confirmation back to client
			response := map[string]interface{}{
				"type":       "ptt_start_confirmed",
				"message_id": c.currentMessageeID,
			}
			if responseData, e := json.Marshal(response); e == nil {
				select {
				case c.send <- responseData:
				default:
					log.Printf("[HUB] [PTT] Failed to send PTT confirmation to client %s", c.ID)
				}
			}
		} else {
			// Speaker slot is occupied - get current speaker info
			currentSpeakerID := c.hub.redis.Get(ctx, speakerLockKey).Val()

			log.Printf("[HUB] [PTT] User %d failed to acquire speaker lock for channel %s (held by %s)", c.UserID, c.ChannelID, currentSpeakerID)

			// Send busy signal back to client
			busyResponse := map[string]interface{}{
				"type":            "ptt_busy",
				"current_speaker": currentSpeakerID,
			}
			if responseData, e := json.Marshal(busyResponse); e == nil {
				select {
				case c.send <- responseData:
				default:
					log.Printf("[HUB] [PTT] Failed to send PTT busy signal to client %s", c.ID)
				}
			}
		}

	case "ptt stop":
		if c.isRecording {
			speakerLockKey := fmt.Sprintf("channel:%s:speaker", c.ChannelID)

			// Only allow the current speaker to release the lock
			currentSpeaker := c.hub.redis.Get(ctx, speakerLockKey).Val()
			if currentSpeaker == fmt.Sprintf("%d", c.UserID) {
				c.hub.redis.Del(ctx, speakerLockKey)
				c.isRecording = false

				log.Printf("[HUB] [PTT] User %d released speaker lock for channel %s", c.UserID, c.ChannelID)

				// Notify other clients that speaking has stopped
				speakerNotification := map[string]interface{}{
					"type":       "speaker_inactive",
					"user_id":    c.UserID,
					"channel_id": c.ChannelID,
					"message_id": c.currentMessageeID,
				}

				if notificationData, e := json.Marshal(speakerNotification); e == nil {
					message := &Message{
						ChannelID: c.ChannelID,
						Data:      notificationData,
						Sender:    c,
					}
					c.hub.broadcast <- message
				}

				// Send confirmation back to client
				response := map[string]interface{}{
					"type":       "ptt_stop_confirmed",
					"message_id": c.currentMessageeID,
				}
				if responseData, e := json.Marshal(response); e == nil {
					select {
					case c.send <- responseData:
					default:
						log.Printf("[HUB] [PTT] Failed to send PTT stop confirmation to client %s", c.ID)
					}
				}

				c.currentMessageeID = ""
			} else {
				log.Printf("[HUB] [PTT] User %d attempted to release speaker lock for channel %s but is not the current speaker", c.UserID, c.ChannelID)
			}
		}

	case "channel_change":
		// Handle channel change requests from client
		var payload struct {
			NewChannelID string `json:"new_channel_id"`
		}
		
		if err := json.Unmarshal(s.Payload, &payload); err != nil {
			log.Printf("[HUB] [CHN] Failed to unmarshal channel_change payload: %v", err)
			return
		}

		if payload.NewChannelID == "" {
			log.Printf("[HUB] [CHN] Invalid channel change request: empty channel ID")
			return
		}

		// Create channel change request
		req := &ChannelChangeRequest{
			Client:       c,
			NewChannelID: payload.NewChannelID,
		}

		// Send to hub for processing
		select {
		case c.hub.changeChannel <- req:
			log.Printf("[HUB] [CHN] Channel change request submitted for user %d: %s -> %s", c.UserID, c.ChannelID, payload.NewChannelID)
		default:
			log.Printf("[HUB] [CHN] Failed to submit channel change request for user %d", c.UserID)
		}

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
			w, e := c.conn.NextWriter(websocket.BinaryMessage)
			if e != nil {
				log.Printf("[WBS] [WRT] Something went wrong while preparing the writer: %s", e)
				return
			}
			w.Write(msg)
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write(<-c.send)
			}
			if e := w.Close(); e != nil {
				log.Printf("[WBS] [CLS] Something went wrong while closing the WebSocket connection: %s", e)
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(waitOnReceiving))
			if e := c.conn.WriteMessage(websocket.PingMessage, nil); e != nil {
				log.Printf("[WBS] [PNG] Something went wrong with the client: %s", e)
				return
			}
		}
	}
}

// Redis helper functions for caching and session management

// GetChannelUsers returns list of user IDs currently in a channel
func (h *Hub) GetChannelUsers(channelID string) ([]string, error) {
	ctx := context.Background()
	users := h.redis.SMembers(ctx, fmt.Sprintf("channel:%s:users", channelID))
	return users.Val(), users.Err()
}

// GetUserSession returns the session ID for a user
func (h *Hub) GetUserSession(userID int) (string, error) {
	ctx := context.Background()
	session := h.redis.Get(ctx, fmt.Sprintf("user:%d:session", userID))
	return session.Val(), session.Err()
}

// GetUserCurrentChannel returns the current channel for a user
func (h *Hub) GetUserCurrentChannel(userID int) (string, error) {
	ctx := context.Background()
	channel := h.redis.Get(ctx, fmt.Sprintf("user:%d:channel", userID))
	return channel.Val(), channel.Err()
}

// IsChannelSpeakerActive checks if someone is currently speaking in a channel
func (h *Hub) IsChannelSpeakerActive(channelID string) (bool, string, error) {
	ctx := context.Background()
	speakerLockKey := fmt.Sprintf("channel:%s:speaker", channelID)
	speaker := h.redis.Get(ctx, speakerLockKey)

	if speaker.Err() != nil {
		if speaker.Err().Error() == "redis: nil" {
			return false, "", nil // No active speaker
		}
		return false, "", speaker.Err()
	}

	return true, speaker.Val(), nil
}

// SetChannelCache caches channel information
func (h *Hub) SetChannelCache(channelID, channelName string, eventUUID *string) error {
	ctx := context.Background()
	channelData := map[string]interface{}{
		"name":       channelName,
		"created_at": time.Now().Unix(),
	}
	if eventUUID != nil {
		channelData["event_uuid"] = *eventUUID
	}

	data, e := json.Marshal(channelData)
	if e != nil {
		return e
	}

	return h.redis.Set(ctx, fmt.Sprintf("channel:%s:info", channelID), string(data), time.Hour).Err()
}

// GetChannelCache retrieves cached channel information
func (h *Hub) GetChannelCache(channelID string) (map[string]interface{}, error) {
	ctx := context.Background()
	data := h.redis.Get(ctx, fmt.Sprintf("channel:%s:info", channelID))

	if data.Err() != nil {
		return nil, data.Err()
	}

	var channelData map[string]interface{}
	e := json.Unmarshal([]byte(data.Val()), &channelData)
	return channelData, e
}

// SetUserCache caches user information
func (h *Hub) SetUserCache(userID int, username, email string) error {
	ctx := context.Background()
	return h.redis.HMSet(ctx, fmt.Sprintf("user:%d:info", userID), map[string]interface{}{
		"username":  username,
		"email":     email,
		"last_seen": time.Now().Unix(),
	}).Err()
}

// GetUserCache retrieves cached user information
func (h *Hub) GetUserCache(userID int) (map[string]string, error) {
	ctx := context.Background()
	userData := h.redis.HGetAll(ctx, fmt.Sprintf("user:%d:info", userID))
	return userData.Val(), userData.Err()
}

// CleanupExpiredSessions removes expired user sessions and locks
func (h *Hub) CleanupExpiredSessions() {
	// This could be run periodically to clean up expired data
	// For now, we rely on Redis TTL for automatic cleanup
	log.Println("[HUB] [CLEANUP] Redis TTL handles automatic cleanup of expired sessions")
}
