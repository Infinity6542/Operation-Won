// WebSocket hub implementation for managing client connections and message broadcasting
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
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
	currentMessageID  string
	encryptionEnabled bool
	publicKey         string
	encryptionStatus  int
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

			// Use Redis pipeline for multiple operations to improve performance
			ctx := context.Background()
			pipe := h.redis.Pipeline()
			pipe.SAdd(ctx, fmt.Sprintf("channel:%s:users", client.ChannelID), client.UserID)
			pipe.Set(ctx, fmt.Sprintf("user:%d:session", client.UserID), client.ID, 30*time.Minute)
			pipe.Set(ctx, fmt.Sprintf("user:%d:channel", client.UserID), client.ChannelID, 30*time.Minute)
			_, err := pipe.Exec(ctx)
			if err != nil {
				log.Printf("[HUB] [ERR] Failed to execute Redis pipeline for client registration: %v", err)
			}

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

			// Use Redis pipeline for cleanup operations
			pipe := h.redis.Pipeline()
			pipe.SRem(ctx, fmt.Sprintf("channel:%s:users", c.ChannelID), c.UserID)
			pipe.Del(ctx, fmt.Sprintf("user:%d:session", c.UserID))
			pipe.Del(ctx, fmt.Sprintf("user:%d:channel", c.UserID))

			if len(room) == 0 {
				// Clean up empty channel data from Redis
				pipe.Del(ctx, fmt.Sprintf("channel:%s:users", c.ChannelID))
			}

			_, err := pipe.Exec(ctx)
			if err != nil {
				log.Printf("[HUB] [ERR] Failed to execute Redis cleanup pipeline: %v", err)
			}

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

	log.Printf("[HUB] [BROADCAST] Broadcasting %d bytes to channel %s, sender: %s (UserID: %d)", len(message.Data), message.ChannelID, message.Sender.ID, message.Sender.UserID)
	clientCount := 0
	for client := range channelClients {
		if client != message.Sender {
			log.Printf("[HUB] [BROADCAST] Sending to client %s (UserID: %d)", client.ID, client.UserID)
			select {
			case client.send <- message.Data:
				clientCount++
			default:
				close(client.send)
				delete(channelClients, client)
			}
		} else {
			log.Printf("[HUB] [BROADCAST] Skipping sender %s (UserID: %d)", client.ID, client.UserID)
		}
	}
	log.Printf("[HUB] [BROADCAST] Sent to %d clients", clientCount)
}

func (h *Hub) switchChannel(req *ChannelChangeRequest) {
	h.mu.Lock()
	defer h.mu.Unlock()

	ctx := context.Background()
	oldChannelID := req.Client.ChannelID

	// Remove from old channel
	if oldRoom, ok := h.channels[req.Client.ChannelID]; ok {
		delete(oldRoom, req.Client)

		// Use Redis pipeline for channel switch operations
		pipe := h.redis.Pipeline()
		pipe.SRem(ctx, fmt.Sprintf("channel:%s:users", oldChannelID), req.Client.UserID)

		if len(oldRoom) == 0 {
			pipe.Del(ctx, fmt.Sprintf("channel:%s:users", oldChannelID))
		}

		// Add to new channel
		req.Client.ChannelID = req.NewChannelID
		if _, ok := h.channels[req.NewChannelID]; !ok {
			h.channels[req.NewChannelID] = make(map[*Client]bool)
		}
		h.channels[req.NewChannelID][req.Client] = true

		// Update Redis - add to new channel
		pipe.SAdd(ctx, fmt.Sprintf("channel:%s:users", req.NewChannelID), req.Client.UserID)
		pipe.Set(ctx, fmt.Sprintf("user:%d:channel", req.Client.UserID), req.NewChannelID, 30*time.Minute)

		_, err := pipe.Exec(ctx)
		if err != nil {
			log.Printf("[HUB] [ERR] Failed to execute Redis channel switch pipeline: %v", err)
		}

		if len(oldRoom) == 0 {
			delete(h.channels, oldChannelID)
		}
	}

	log.Printf("[HUB] [CHN] [MVE] User %s moved from channel %s to %s", req.Client.ID, oldChannelID, req.NewChannelID)
}

// WebSocket handling constants
const (
	maxMessageSize  = 8192             // Increased for larger audio chunks
	pongWait        = 60 * time.Second // Increased timeout
	pingInterval    = pongWait * 9 / 10
	waitOnReceiving = 20 * time.Second // Increased timeout
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
				log.Printf("[WBS] [MSG] Invalid message from client %s: %v", c.ID, e)
				continue
			}
			c.handleSignal(s)
		case websocket.BinaryMessage:
			log.Printf("[WBS] [BIN] Received binary message: %d bytes, isRecording: %v, messageID: %s", len(messageData), c.isRecording, c.currentMessageID)
			if c.encryptionStatus == 1 {
				var exchange struct {
					ChannelID string `json:"channel_id"`
					PublicKey string `json:"public_key"`
					UserID    int    `json:"user_id"`
				}
				err := json.Unmarshal(messageData, &exchange)
				if err != nil {
					log.Printf("[WBS] [KEY] Failed to unmarshal key exchange data: %v", err)
					return
				}

				c.publicKey = exchange.PublicKey
				c.encryptionEnabled = true

				log.Printf("[WBS] [KEY] Client %s (UserID: %d) initiated key exchange in channel %s", c.ID, c.UserID, exchange.ChannelID)

				ctx := context.Background()
				keyStorageKey := fmt.Sprintf("channel:%s:keys:%d", exchange.ChannelID, c.UserID)
				err = c.hub.redis.Set(ctx, keyStorageKey, exchange.PublicKey, 24*time.Hour).Err()
				if err != nil {
					log.Printf("[WBS] [KEY] Failed to store public key in Redis: %v", err)
				}

				keyExchangeResponse := map[string]interface{}{
					"type":       "key_exchange_broadcast",
					"user_id":    c.UserID,
					"channel_id": exchange.ChannelID,
					"public_key": c.publicKey,
					"timestamp":  time.Now().Unix(),
				}

				if responseData, e := json.Marshal(keyExchangeResponse); e == nil {
					msg := &Message{ChannelID: exchange.ChannelID, Data: responseData, Sender: c}
					c.hub.broadcast <- msg
				}

				c.encryptionStatus = 2
			} else if c.encryptionEnabled && c.isRecording {
				log.Printf("[WBS] [ENC] Received encrypted audio: %d bytes from client %s", len(messageData), c.ID)

				msg := &Message{ChannelID: c.ChannelID, Data: messageData, Sender: c}
				c.hub.broadcast <- msg

				if c.currentMessageID != "" {
					file := fmt.Sprintf("./audio/%s_encrypted.opus", c.currentMessageID)
					if err := os.MkdirAll("./audio", os.ModePerm); err != nil {
						log.Printf("[REC] [DIR] Failed to create audio directory: %v", err)
					} else {
						if f, e := os.OpenFile(file, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644); e == nil {
							f.Write(messageData)
							f.Close()
							log.Printf("[REC] [ENC] Appended audio chunk to %s", file)
						}
					}
				}
			} else if c.isRecording {
				file := fmt.Sprintf("./audio/%s.opus", c.currentMessageID)

				// Check if directory exists and create if necessary
				if err := os.MkdirAll("./audio", os.ModePerm); err != nil {
					log.Printf("[REC] [DIR] Failed to create audio directory: %v", err)
					continue
				}

				f, e := os.OpenFile(file, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
				if e != nil {
					log.Printf("[REC] [OPN] Failed to open file %s: %v", file, e)
					continue
				}

				bytesWritten, e := f.Write(messageData)
				if e != nil {
					log.Printf("[REC] [WRT] Failed to write to file %s: %v", file, e)
					f.Close()
					continue
				}
				f.Close()

				// Verify file exists after writing
				if stat, err := os.Stat(file); err != nil {
					log.Printf("[REC] [ERR] File %s does not exist after writing: %v", file, err)
				} else {
					log.Printf("[REC] [SUC] Successfully wrote %d bytes to %s (total size: %d bytes)", bytesWritten, file, stat.Size())
				}

				msg := &Message{ChannelID: c.ChannelID, Data: messageData, Sender: c}
				c.hub.broadcast <- msg
			} else {
				log.Printf("[WBS] [BIN] Ignoring binary message - not recording")
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
			c.currentMessageID = fmt.Sprintf("%d-%d", c.UserID, time.Now().Unix())

			log.Printf("[HUB] [PTT] User %d acquired speaker lock for channel %s, messageID: %s", c.UserID, c.ChannelID, c.currentMessageID)

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
				"message_id": c.currentMessageID,
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

				// Check if audio file still exists when stopping
				if c.currentMessageID != "" {
					audioFile := fmt.Sprintf("./audio/%s.opus", c.currentMessageID)
					if stat, err := os.Stat(audioFile); err != nil {
						log.Printf("[PTT] [STOP] Audio file %s missing on PTT stop: %v", audioFile, err)
					} else {
						log.Printf("[PTT] [STOP] Audio file %s exists on PTT stop (size: %d bytes)", audioFile, stat.Size())

						// List all files in audio directory for debugging
						if files, err := os.ReadDir("./audio"); err != nil {
							log.Printf("[PTT] [STOP] Failed to read audio directory: %v", err)
						} else {
							log.Printf("[PTT] [STOP] Audio directory contains %d files:", len(files))
							for _, file := range files {
								if fileInfo, err := file.Info(); err == nil {
									log.Printf("[PTT] [STOP]   - %s (%d bytes)", file.Name(), fileInfo.Size())
								}
							}
						}
					}
				}

				log.Printf("[HUB] [PTT] User %d released speaker lock for channel %s", c.UserID, c.ChannelID)

				// Notify other clients that speaking has stopped
				speakerNotification := map[string]interface{}{
					"type":       "speaker_inactive",
					"user_id":    c.UserID,
					"channel_id": c.ChannelID,
					"message_id": c.currentMessageID,
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
					"message_id": c.currentMessageID,
				}
				if responseData, e := json.Marshal(response); e == nil {
					select {
					case c.send <- responseData:
					default:
						log.Printf("[HUB] [PTT] Failed to send PTT stop confirmation to client %s", c.ID)
					}
				}

				c.currentMessageID = ""
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
	case "key_exchange":
		c.encryptionStatus = 1
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

			// Determine message type - if it's valid JSON, send as text, otherwise as binary
			var messageType int
			if json.Valid(msg) {
				messageType = websocket.TextMessage
				log.Printf("[WBS] [WRT] Sending text message: %d bytes", len(msg))
			} else {
				messageType = websocket.BinaryMessage
				log.Printf("[WBS] [WRT] Sending binary message: %d bytes", len(msg))
			}

			w, e := c.conn.NextWriter(messageType)
			if e != nil {
				log.Printf("[WBS] [WRT] Something went wrong while preparing the writer: %s", e)
				return
			}
			w.Write(msg)
			n := len(c.send)
			for i := 0; i < n; i++ {
				additionalMsg := <-c.send
				// For additional messages in queue, also check type
				if json.Valid(additionalMsg) && messageType == websocket.TextMessage {
					w.Write(additionalMsg)
				} else if !json.Valid(additionalMsg) && messageType == websocket.BinaryMessage {
					w.Write(additionalMsg)
				} else {
					// If message types don't match, we need to send separately
					// Put it back and handle in next iteration
					select {
					case c.send <- additionalMsg:
					default:
						// Channel full, skip this message
					}
					break
				}
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

// GetUserStatus returns user session, channel, and speaker status efficiently using pipeline
func (h *Hub) GetUserStatus(userID int) (sessionID, currentChannel, speakerChannel string, isSpeaker bool) {
	ctx := context.Background()

	// Use pipeline to get all user status information in one round trip
	pipe := h.redis.Pipeline()
	sessionCmd := pipe.Get(ctx, fmt.Sprintf("user:%d:session", userID))
	channelCmd := pipe.Get(ctx, fmt.Sprintf("user:%d:channel", userID))

	_, err := pipe.Exec(ctx)
	if err != nil {
		log.Printf("[HUB] [ERR] Failed to get user status: %v", err)
		return "", "", "", false
	}

	sessionID = sessionCmd.Val()
	currentChannel = channelCmd.Val()

	// If user is in a channel, check if they're the current speaker
	if currentChannel != "" {
		speakerLockKey := fmt.Sprintf("channel:%s:speaker", currentChannel)
		speaker := h.redis.Get(ctx, speakerLockKey)
		if speaker.Val() == fmt.Sprintf("%d", userID) {
			isSpeaker = true
			speakerChannel = currentChannel
		}
	}

	return sessionID, currentChannel, speakerChannel, isSpeaker
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
	ctx := context.Background()

	// Get all session keys
	sessionKeys, err := h.redis.Keys(ctx, "user:*:session").Result()
	if err != nil {
		log.Printf("[HUB] [CLEANUP] [ERR] Failed to get session keys: %v", err)
		return
	}

	// Get all speaker lock keys
	speakerKeys, err := h.redis.Keys(ctx, "channel:*:speaker").Result()
	if err != nil {
		log.Printf("[HUB] [CLEANUP] [ERR] Failed to get speaker keys: %v", err)
		return
	}

	cleanupCount := 0

	// Use pipeline for efficient cleanup operations
	pipe := h.redis.Pipeline()

	// Check for expired sessions and their associated data
	for _, key := range sessionKeys {
		ttl := h.redis.TTL(ctx, key).Val()
		if ttl < 0 { // Key exists but has no TTL set, or is expired
			// Extract user ID from key pattern "user:123:session"
			parts := strings.Split(key, ":")
			if len(parts) == 3 {
				userID := parts[1]
				// Clean up all user-related keys
				pipe.Del(ctx, key)
				pipe.Del(ctx, fmt.Sprintf("user:%s:channel", userID))
				pipe.Del(ctx, fmt.Sprintf("user:%s:info", userID))
				cleanupCount++
			}
		}
	}

	// Check for orphaned speaker locks (no corresponding active session)
	for _, speakerKey := range speakerKeys {
		speakerUserID := h.redis.Get(ctx, speakerKey).Val()
		if speakerUserID != "" {
			sessionKey := fmt.Sprintf("user:%s:session", speakerUserID)
			exists := h.redis.Exists(ctx, sessionKey).Val()
			if exists == 0 {
				// No active session for this speaker, remove the lock
				pipe.Del(ctx, speakerKey)
				cleanupCount++
				log.Printf("[HUB] [CLEANUP] Removed orphaned speaker lock: %s", speakerKey)
			}
		}
	}

	if cleanupCount > 0 {
		_, err := pipe.Exec(ctx)
		if err != nil {
			log.Printf("[HUB] [CLEANUP] [ERR] Failed to execute cleanup pipeline: %v", err)
		} else {
			log.Printf("[HUB] [CLEANUP] Cleaned up %d expired/orphaned Redis keys", cleanupCount)
		}
	}
}

// CheckRedisHealth verifies Redis connection and performance
func (h *Hub) CheckRedisHealth() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Test basic connectivity
	pong := h.redis.Ping(ctx)
	if pong.Err() != nil {
		return fmt.Errorf("redis ping failed: %v", pong.Err())
	}

	// Test write/read operations
	testKey := "health_check"
	testValue := fmt.Sprintf("test_%d", time.Now().Unix())

	err := h.redis.Set(ctx, testKey, testValue, time.Minute).Err()
	if err != nil {
		return fmt.Errorf("redis write test failed: %v", err)
	}

	val, err := h.redis.Get(ctx, testKey).Result()
	if err != nil {
		return fmt.Errorf("redis read test failed: %v", err)
	}

	if val != testValue {
		return fmt.Errorf("redis data integrity test failed")
	}

	// Clean up test key
	h.redis.Del(ctx, testKey)

	return nil
}

// RedisWithRetry executes a Redis operation with retry logic
func (h *Hub) RedisWithRetry(operation func() error, maxRetries int) error {
	var lastErr error
	for i := 0; i <= maxRetries; i++ {
		err := operation()
		if err == nil {
			return nil
		}

		lastErr = err
		if i < maxRetries {
			// Exponential backoff: 10ms, 20ms, 40ms, 80ms, etc.
			backoff := time.Duration(10*(1<<i)) * time.Millisecond
			time.Sleep(backoff)
			log.Printf("[HUB] [REDIS] [RETRY] Attempt %d/%d failed, retrying in %v: %v",
				i+1, maxRetries+1, backoff, err)
		}
	}
	return fmt.Errorf("redis operation failed after %d retries: %v", maxRetries+1, lastErr)
}

// Key management functions for encryption

// StoreUserPublicKey stores a user's public key for a channel
func (h *Hub) StoreUserPublicKey(channelID string, userID int, publicKey string) error {
	ctx := context.Background()
	key := fmt.Sprintf("channel:%s:keys:%d", channelID, userID)
	return h.redis.Set(ctx, key, publicKey, 24*time.Hour).Err()
}

// GetUserPublicKey retrieves a user's public key for a channel
func (h *Hub) GetUserPublicKey(channelID string, userID int) (string, error) {
	ctx := context.Background()
	key := fmt.Sprintf("channel:%s:keys:%d", channelID, userID)
	return h.redis.Get(ctx, key).Result()
}

// GetChannelPublicKeys retrieves all public keys for users in a channel
func (h *Hub) GetChannelPublicKeys(channelID string) (map[string]string, error) {
	ctx := context.Background()
	pattern := fmt.Sprintf("channel:%s:keys:*", channelID)

	keys, err := h.redis.Keys(ctx, pattern).Result()
	if err != nil {
		return nil, err
	}

	result := make(map[string]string)
	if len(keys) > 0 {
		values, err := h.redis.MGet(ctx, keys...).Result()
		if err != nil {
			return nil, err
		}

		for i, key := range keys {
			if i < len(values) && values[i] != nil {
				// Extract user ID from key pattern "channel:xxx:keys:123"
				parts := strings.Split(key, ":")
				if len(parts) >= 4 {
					userID := parts[3]
					result[userID] = values[i].(string)
				}
			}
		}
	}

	return result, nil
}

// CleanupChannelKeys removes all encryption keys for a channel
func (h *Hub) CleanupChannelKeys(channelID string) error {
	ctx := context.Background()
	pattern := fmt.Sprintf("channel:%s:keys:*", channelID)

	keys, err := h.redis.Keys(ctx, pattern).Result()
	if err != nil {
		return err
	}

	if len(keys) > 0 {
		return h.redis.Del(ctx, keys...).Err()
	}

	return nil
}
