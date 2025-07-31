package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/go-sql-driver/mysql"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

var secret = []byte(getEnv("JWT_SECRET", "verymuchasecr3t"))

// Define a custom type for context keys to avoid collisions
type contextKey string

const userIDKey contextKey = "userID"

// Test mode flag to disable rate limiting during tests
var testMode = false

// EnableTestMode disables rate limiting for testing
func EnableTestMode() {
	testMode = true
}

// DisableTestMode re-enables rate limiting
func DisableTestMode() {
	testMode = false
}

// Rate limiting structures
type RateLimiter struct {
	requests map[string][]time.Time
	mu       sync.RWMutex
	limit    int
	window   time.Duration
}

type JWTBlacklist struct {
	tokens map[string]time.Time
	mu     sync.RWMutex
}

var (
	authRateLimiter = NewRateLimiter(5, time.Minute) // 5 requests per minute for auth
	jwtBlacklist    = NewJWTBlacklist()
)

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
}

func NewJWTBlacklist() *JWTBlacklist {
	return &JWTBlacklist{
		tokens: make(map[string]time.Time),
	}
}

func (rl *RateLimiter) IsAllowed(clientIP string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-rl.window)

	// Clean old requests
	requests := rl.requests[clientIP]
	validRequests := make([]time.Time, 0)
	for _, req := range requests {
		if req.After(windowStart) {
			validRequests = append(validRequests, req)
		}
	}

	// Check if limit exceeded
	if len(validRequests) >= rl.limit {
		return false
	}

	// Add current request
	validRequests = append(validRequests, now)
	rl.requests[clientIP] = validRequests
	return true
}

func (rl *RateLimiter) Cleanup() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	for clientIP, requests := range rl.requests {
		validRequests := make([]time.Time, 0)
		windowStart := now.Add(-rl.window)

		for _, req := range requests {
			if req.After(windowStart) {
				validRequests = append(validRequests, req)
			}
		}

		if len(validRequests) == 0 {
			delete(rl.requests, clientIP)
		} else {
			rl.requests[clientIP] = validRequests
		}
	}
}

func (jb *JWTBlacklist) Add(tokenID string, expiry time.Time) {
	jb.mu.Lock()
	defer jb.mu.Unlock()
	jb.tokens[tokenID] = expiry
}

func (jb *JWTBlacklist) IsBlacklisted(tokenID string) bool {
	jb.mu.RLock()
	defer jb.mu.RUnlock()

	expiry, exists := jb.tokens[tokenID]
	if !exists {
		return false
	}

	// Clean expired tokens
	if time.Now().After(expiry) {
		delete(jb.tokens, tokenID)
		return false
	}

	return true
}

func (jb *JWTBlacklist) Cleanup() {
	jb.mu.Lock()
	defer jb.mu.Unlock()

	now := time.Now()
	for tokenID, expiry := range jb.tokens {
		if now.After(expiry) {
			delete(jb.tokens, tokenID)
		}
	}
}

type User struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Email    string `json:"email"`
}

type Server struct {
	hub   *Hub
	db    *sql.DB
	redis *redis.Client
}

type AuthPayload struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type CrtChannel struct {
	EventUUID   *string `json:"event_uuid"`
	ChannelName string  `json:"channel_name"`
}

type ChannelResponse struct {
	ChannelUUID string  `json:"channel_uuid"`
	ChannelName string  `json:"channel_name"`
	EventUUID   *string `json:"event_uuid"`
	IsCreator   bool    `json:"is_creator"`
}

type CrtEvent struct {
	EventName        string `json:"event_name"`
	EventDescription string `json:"event_description"`
}

type EventResponse struct {
	EventUUID        string `json:"event_uuid"`
	EventName        string `json:"event_name"`
	EventDescription string `json:"event_description"`
	IsOrganiser      bool   `json:"is_organiser"`
}

func NewServer(hub *Hub, db *sql.DB, redis *redis.Client) *Server {
	return &Server{
		hub:   hub,
		db:    db,
		redis: redis,
	}
}

func (s *Server) HandleAuth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Rate limiting check (skip during tests)
	if !testMode {
		clientIP := r.RemoteAddr
		if !authRateLimiter.IsAllowed(clientIP) {
			log.Printf("[AUT] [RATE] Rate limit exceeded for IP: %s", clientIP)
			http.Error(w, "Too many authentication attempts. Please try again later.", http.StatusTooManyRequests)
			return
		}
	}

	if s.db == nil {
		log.Println("[ERR] [DTB] Database is nil")
		http.Error(w, "Internal server error.", http.StatusInternalServerError)
		return
	}

	defer r.Body.Close()

	var payload AuthPayload
	e := json.NewDecoder(r.Body).Decode(&payload)
	if e != nil {
		fmt.Println(e)
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	log.Printf("[AUT] [LGN] Received payload - Username: '%s', Email: '%s'", payload.Username, payload.Email)

	var hash string
	var uid int
	var username string

	// Try to find user by email first, then by username
	var loginIdentifier string
	if payload.Email != "" {
		loginIdentifier = payload.Email
		log.Printf("[AUT] [LGN] Login attempt with email: %s", payload.Email)
	} else if payload.Username != "" {
		loginIdentifier = payload.Username
		log.Printf("[AUT] [LGN] Login attempt with username: %s", payload.Username)
	} else {
		log.Printf("[AUT] [LGN] No username or email provided")
		http.Error(w, "Username or email is required.", http.StatusBadRequest)
		return
	}

	// First try email lookup
	query := "SELECT id, username, hashed_password FROM users WHERE email = ?"
	log.Printf("[AUT] [LGN] Trying email query with identifier: %s", loginIdentifier)
	err := s.db.QueryRow(query, loginIdentifier).Scan(&uid, &username, &hash)

	// If email lookup fails and the identifier doesn't contain @, try username lookup
	if err == sql.ErrNoRows && !strings.Contains(loginIdentifier, "@") {
		query = "SELECT id, username, hashed_password FROM users WHERE username = ?"
		log.Printf("[AUT] [LGN] Email lookup failed, trying username query with: %s", loginIdentifier)
		err = s.db.QueryRow(query, loginIdentifier).Scan(&uid, &username, &hash)
	}

	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("[AUT] [LGN] User not found: %s", loginIdentifier)
			http.Error(w, "Invalid credentials.", http.StatusUnauthorized)
			return
		}
		fmt.Printf("[AUT] [LGN] Something went wrong when searching for the user: %v\n", err)
		http.Error(w, "Invalid credentials.", http.StatusUnauthorized)
		return
	}

	auth := bcrypt.CompareHashAndPassword([]byte(hash), []byte(payload.Password))
	if auth != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		fmt.Printf("[AUT] [LGN] Incorrect password for user %s\n", username)
		return
	}

	// Create token with JTI (JWT ID) for blacklisting capability
	jti := uuid.New().String()
	now := time.Now()
	expiry := now.Add(time.Hour * 48)

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"jti":      jti,
		"user_id":  uid,
		"username": username,
		"iat":      now.Unix(),
		"exp":      expiry.Unix(),
	})

	tokenString, e := token.SignedString(secret)
	if e != nil {
		log.Printf("[AUT] [TKN] Failed to create a token: %s", e)
		http.Error(w, "Failed to create the token.", http.StatusInternalServerError)
		return
	}

	// Cache user information in Redis
	if s.hub != nil {
		s.hub.SetUserCache(uid, username, payload.Email)
	}

	log.Printf("[AUT] [LGN] User %s successfully authenticated", username)
	json.NewEncoder(w).Encode(map[string]string{"token": tokenString})
}

func (s *Server) HandleRefreshToken(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		http.Error(w, "Missing authorization header.", http.StatusUnauthorized)
		return
	}

	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == authHeader {
		http.Error(w, "Invalid token format.", http.StatusUnauthorized)
		return
	}

	claims := &jwt.MapClaims{}
	_, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return secret, nil
	})

	// For refresh, we allow expired tokens as long as they're properly signed
	if err != nil {
		// Check if the error is just due to expiration
		if strings.Contains(err.Error(), "token is expired") {
			// Token is expired but otherwise valid - this is OK for refresh
			log.Printf("[AUT] [REF] Accepting expired token for refresh")
		} else {
			// Token has other validation errors
			log.Printf("[AUT] [REF] Token validation error: %v", err)
			http.Error(w, "Invalid token.", http.StatusUnauthorized)
			return
		}
	}

	// Check if token is blacklisted
	jti, ok := (*claims)["jti"].(string)
	if ok && jwtBlacklist.IsBlacklisted(jti) {
		http.Error(w, "Token has been revoked.", http.StatusUnauthorized)
		return
	}

	// Extract user information
	userID, ok := (*claims)["user_id"].(float64)
	if !ok {
		http.Error(w, "Invalid token claims.", http.StatusUnauthorized)
		return
	}

	username, ok := (*claims)["username"].(string)
	if !ok {
		http.Error(w, "Invalid token claims.", http.StatusUnauthorized)
		return
	}

	// Create new token
	newJTI := uuid.New().String()
	now := time.Now()
	expiry := now.Add(time.Hour * 48)

	newToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"jti":      newJTI,
		"user_id":  int(userID),
		"username": username,
		"iat":      now.Unix(),
		"exp":      expiry.Unix(),
	})

	newTokenString, err := newToken.SignedString(secret)
	if err != nil {
		log.Printf("[AUT] [REF] Failed to create refresh token: %s", err)
		http.Error(w, "Failed to refresh token.", http.StatusInternalServerError)
		return
	}

	// Blacklist the old token
	if jti != "" {
		exp, ok := (*claims)["exp"].(float64)
		if ok {
			expiryTime := time.Unix(int64(exp), 0)
			jwtBlacklist.Add(jti, expiryTime)
		}
	}

	log.Printf("[AUT] [REF] Token refreshed for user %s", username)
	json.NewEncoder(w).Encode(map[string]string{"token": newTokenString})
}

func (s *Server) HandleLogout(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		http.Error(w, "Missing authorization header.", http.StatusUnauthorized)
		return
	}

	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == authHeader {
		http.Error(w, "Invalid token format.", http.StatusUnauthorized)
		return
	}

	claims := &jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return secret, nil
	})

	if err != nil || !token.Valid {
		http.Error(w, "Invalid token.", http.StatusUnauthorized)
		return
	}

	// Blacklist the token
	if jti, ok := (*claims)["jti"].(string); ok {
		if exp, ok := (*claims)["exp"].(float64); ok {
			expiryTime := time.Unix(int64(exp), 0)
			jwtBlacklist.Add(jti, expiryTime)
			log.Printf("[AUT] [LOGOUT] Token blacklisted: %s", jti)
		}
	}

	// Clean up user session from Redis
	if userID, ok := (*claims)["user_id"].(float64); ok && s.hub != nil {
		ctx := context.Background()
		s.hub.redis.Del(ctx, fmt.Sprintf("user:%d:session", int(userID)))
		s.hub.redis.Del(ctx, fmt.Sprintf("user:%d:channel", int(userID)))
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"message": "Logged out successfully"})
}

func (s *Server) HandleRegister(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var payload AuthPayload
	e := json.NewDecoder(r.Body).Decode(&payload)
	if e != nil {
		fmt.Println(e)
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}

	defer r.Body.Close()

	if payload.Email == "" || payload.Password == "" || payload.Username == "" {
		http.Error(w, "Username, email and password are empty.", http.StatusBadRequest)
		return
	}

	if s.db == nil {
		log.Println("[ERR] [DTB] Database is nil")
		http.Error(w, "Internal server error.", http.StatusInternalServerError)
		return
	}

	pass, e := bcrypt.GenerateFromPassword([]byte(payload.Password), bcrypt.DefaultCost)
	if e != nil {
		fmt.Printf("[AUT] [REG] Error while attempting to hash password: %v", e)
		http.Error(w, "Failed to process request.", http.StatusInternalServerError)
		return
	}

	uuid := uuid.New().String()

	result, e := s.db.Exec("INSERT INTO users (user_uuid, username, email, hashed_password) VALUES (?, ?, ?, ?)", uuid, payload.Username, payload.Email, string(pass))
	if e != nil {
		fmt.Printf("[AUT] [REG] Error while adding user to the database: %v\n", e)

		// Check if it's a MySQL error before casting
		if mysqlErr, ok := e.(*mysql.MySQLError); ok {
			switch mysqlErr.Number {
			case 1046:
				http.Error(w, "A field was too long.", http.StatusBadRequest)
			case 1048:
				http.Error(w, "A sent value cannot be empty.", http.StatusBadRequest)
			case 1062:
				http.Error(w, "The username is not unique.", http.StatusConflict)
			default:
				http.Error(w, "An internal error occurred.", http.StatusInternalServerError)
			}
		} else {
			http.Error(w, "An internal error occurred.", http.StatusInternalServerError)
		}
		return
	} else {
		fmt.Println(result.LastInsertId())
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Registration successful."})
}

func (s *Server) ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	tokenString := r.URL.Query().Get("token")
	if tokenString == "" {
		http.Error(w, "Invalid authentication method.", http.StatusUnauthorized)
		return
	}

	claims := &jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// Validate the signing method to prevent algorithm confusion attacks
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return secret, nil
	})
	if err != nil || !token.Valid {
		http.Error(w, "Invalid token.", http.StatusUnauthorized)
		return
	}

	uidFloat, _ := (*claims)["user_id"].(float64)
	uid := int(uidFloat)

	channelID := r.URL.Query().Get("channel")
	// Allow connections without a channel initially - user can join channel later
	if channelID == "" {
		channelID = "lobby" // Default channel
	}

	conn, e := upgrader.Upgrade(w, r, nil)
	if e != nil {
		log.Printf("[WBS] [UPG] Error while upgrading HTTP to WebSockets: %s", e)
		return
	}

	client := &Client{
		ID:        uuid.New().String(),
		hub:       s.hub,
		conn:      conn,
		send:      make(chan []byte, 256),
		ChannelID: channelID,
		UserID:    uid,
	}

	s.hub.register <- client
	go client.writePump()
	go client.readPump()
}

func (s *Server) Security(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security headers
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")

		// Check for Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			// Also check "auth" header for backward compatibility
			authHeader = r.Header.Get("auth")
		}

		// Skip auth for public routes
		publicRoutes := []string{"/", "/health", "/auth/register", "/auth/login"}
		for _, route := range publicRoutes {
			if r.URL.Path == route {
				next.ServeHTTP(w, r)
				return
			}
		}

		// Require authentication for all other routes
		if authHeader == "" {
			http.Error(w, "Missing authorization header.", http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			http.Error(w, "Invalid token format.", http.StatusUnauthorized)
			return
		}

		claims := &jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			// Validate signing algorithm to prevent algorithm confusion attacks
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return secret, nil
		})

		if err != nil || !token.Valid {
			http.Error(w, "Invalid token.", http.StatusUnauthorized)
			return
		}

		// Check if token is blacklisted
		if jti, ok := (*claims)["jti"].(string); ok {
			if jwtBlacklist.IsBlacklisted(jti) {
				http.Error(w, "Token has been revoked.", http.StatusUnauthorized)
				return
			}
		}

		// Store user ID in context
		if userID, ok := (*claims)["user_id"].(float64); ok {
			ctx := context.WithValue(r.Context(), userIDKey, int(userID))
			r = r.WithContext(ctx)
		}

		next.ServeHTTP(w, r)
	})
}

func (s *Server) CreateChannel(w http.ResponseWriter, r *http.Request) {
	log.Printf("[CHN] [CRT] CreateChannel called")

	uid, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		log.Printf("[CHN] [CRT] Failed to get user ID from context")
		http.Error(w, "Failed to find user.", http.StatusInternalServerError)
		return
	}
	log.Printf("[CHN] [CRT] User ID: %d", uid)

	var payload CrtChannel
	if e := json.NewDecoder(r.Body).Decode(&payload); e != nil {
		log.Printf("[CHN] [CRT] Failed to decode request body: %v", e)
		http.Error(w, "Invalid request.", http.StatusBadRequest)
		return
	}
	log.Printf("[CHN] [CRT] Channel name: %s", payload.ChannelName)

	if payload.ChannelName == "" {
		log.Printf("[CHN] [CRT] Channel name is empty")
		http.Error(w, "Channel name is required.", http.StatusBadRequest)
		return
	}

	var channelUUID = uuid.New().String()
	var lastInsertID int64
	log.Printf("[CHN] [CRT] Generated UUID: %s", channelUUID)

	tx, e := s.db.Begin()
	if e != nil {
		log.Printf("[CHN] [CRT] Failed to begin transaction: %v", e)
		http.Error(w, "Database error.", http.StatusInternalServerError)
		return
	}
	log.Printf("[CHN] [CRT] Transaction started")

	// Event
	if payload.EventUUID != nil && *payload.EventUUID != "" {
		var eventID int
		e := tx.QueryRow("SELECT id FROM events WHERE event_uuid = ? AND organiser_user_id = ?", *payload.EventUUID, uid).Scan(&eventID)
		if e != nil {
			tx.Rollback()
			if e == sql.ErrNoRows {
				http.Error(w, "Event not found or you are not the organiser.", http.StatusForbidden)
				return
			}
			http.Error(w, "Database error.", http.StatusInternalServerError)
			return
		}

		res, e := tx.Exec("INSERT INTO channels (channel_uuid, channel_name, event_id, created_by) VALUES (?, ?, ?, ?)",
			channelUUID, payload.ChannelName, eventID, uid)
		if e != nil {
			tx.Rollback()
			http.Error(w, "Failed to create channel.", http.StatusInternalServerError)
			return
		}

		lastInsertID, _ = res.LastInsertId()
		_, e = tx.Exec("INSERT INTO channel_members (channel_id, user_id, role) VALUES (?, ?, 'admin')",
			lastInsertID, uid)
		if e != nil {
			tx.Rollback()
			http.Error(w, "Failed to add creator to channel.", http.StatusInternalServerError)
			return
		}

	} else { // No event
		log.Printf("[CHN] [CRT] Creating standalone channel")
		res, e := tx.Exec("INSERT INTO channels (channel_uuid, channel_name, event_id, created_by) VALUES (?, ?, NULL, ?)",
			channelUUID, payload.ChannelName, uid)
		if e != nil {
			log.Printf("[CHN] [CRT] Failed to insert channel: %v", e)
			tx.Rollback()
			http.Error(w, "Failed to create channel.", http.StatusInternalServerError)
			return
		}
		lastInsertID, _ = res.LastInsertId()
		log.Printf("[CHN] [CRT] Channel inserted with ID: %d", lastInsertID)

		_, e = tx.Exec("INSERT INTO channel_members (channel_id, user_id, role) VALUES (?, ?, 'admin')",
			lastInsertID, uid)
		if e != nil {
			log.Printf("[CHN] [CRT] Failed to add user to channel: %v", e)
			tx.Rollback()
			http.Error(w, "Failed to add creator to channel.", http.StatusInternalServerError)
			return
		}
		log.Printf("[CHN] [CRT] User added as admin to channel")
	}

	if e := tx.Commit(); e != nil {
		log.Printf("[CHN] [CRT] Failed to commit transaction: %v", e)
		http.Error(w, "Failed to create channel.", http.StatusInternalServerError)
		return
	}
	log.Printf("[CHN] [CRT] Transaction committed successfully")

	log.Printf("[CHN] [CRT] %d created channel %s", uid, payload.ChannelName)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Channel created successfully", "channel_uuid": channelUUID})
}

func (s *Server) GetChannels(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	uid, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		http.Error(w, "Failed to find user.", http.StatusInternalServerError)
		return
	}

	// Modified query to include creator information
	query := `SELECT DISTINCT c.channel_uuid, c.channel_name, e.event_uuid, 
			  (c.created_by = ?) as is_creator
			  FROM channels c 
			  LEFT JOIN events e ON c.event_id = e.id 
			  LEFT JOIN channel_members cm ON c.id = cm.channel_id 
			  LEFT JOIN event_members em ON e.id = em.event_id 
			  WHERE cm.user_id = ? OR em.user_id = ?`

	rows, e := s.db.Query(query, uid, uid, uid)
	if e != nil {
		log.Printf("[CHN] [GET] Failed to get channel list for user %d: %v", uid, e)
		http.Error(w, "Failed to get channel list for user", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var channels []ChannelResponse
	for rows.Next() {
		var ch ChannelResponse
		var eventUUID sql.NullString
		var isCreator bool
		if e := rows.Scan(&ch.ChannelUUID, &ch.ChannelName, &eventUUID, &isCreator); e != nil {
			log.Printf("[CHN] [DTB] Failed to scan channel row: %v", e)
			continue
		}
		if eventUUID.Valid {
			ch.EventUUID = &eventUUID.String
		}
		ch.IsCreator = isCreator
		channels = append(channels, ch)
	}

	// Ensure we always return an array, even if empty
	if channels == nil {
		channels = []ChannelResponse{}
	}

	json.NewEncoder(w).Encode(channels)
}

func (s *Server) CreateEvent(w http.ResponseWriter, r *http.Request) {
	uid, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		http.Error(w, "Failed to find user.", http.StatusInternalServerError)
		return
	}

	var payload CrtEvent
	if e := json.NewDecoder(r.Body).Decode(&payload); e != nil {
		http.Error(w, "Invalid request.", http.StatusBadRequest)
		return
	}
	if payload.EventName == "" {
		http.Error(w, "Event name is required.", http.StatusBadRequest)
		return
	}

	var eventUUID = uuid.New().String()
	var lastInsertID int64

	tx, e := s.db.Begin()
	if e != nil {
		http.Error(w, "Database error.", http.StatusInternalServerError)
		return
	}

	// Create the event
	res, e := tx.Exec("INSERT INTO events (event_uuid, event_name, event_description, organiser_user_id) VALUES (?, ?, ?, ?)",
		eventUUID, payload.EventName, payload.EventDescription, uid)
	if e != nil {
		tx.Rollback()
		http.Error(w, "Failed to create event.", http.StatusInternalServerError)
		return
	}

	lastInsertID, _ = res.LastInsertId()

	// Add the creator as an event member with 'organiser' role
	_, e = tx.Exec("INSERT INTO event_members (event_id, user_id, role) VALUES (?, ?, 'organiser')",
		lastInsertID, uid)
	if e != nil {
		tx.Rollback()
		http.Error(w, "Failed to add creator to event.", http.StatusInternalServerError)
		return
	}

	if e := tx.Commit(); e != nil {
		http.Error(w, "Failed to create event.", http.StatusInternalServerError)
		return
	}

	log.Printf("[EVT] [CRT] %d created event %s", uid, payload.EventName)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Event created successfully", "event_uuid": eventUUID})
}

func (s *Server) GetEvents(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	uid, _ := r.Context().Value(userIDKey).(int)

	query := `SELECT e.event_uuid, e.event_name, e.event_description, 
			  CASE WHEN e.organiser_user_id = ? THEN true ELSE false END as is_organiser
			  FROM events e 
			  INNER JOIN event_members em ON e.id = em.event_id 
			  WHERE em.user_id = ?`

	rows, e := s.db.Query(query, uid, uid)
	if e != nil {
		log.Printf("[EVT] [GET] Failed to get event list for user %d: %v", uid, e)
		http.Error(w, "Failed to get event list for user", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var events []EventResponse
	for rows.Next() {
		var ev EventResponse
		if e := rows.Scan(&ev.EventUUID, &ev.EventName, &ev.EventDescription, &ev.IsOrganiser); e != nil {
			log.Printf("[EVT] [DTB] Failed to scan event row: %v", e)
			continue
		}
		events = append(events, ev)
	}

	// Ensure we always return an array, even if empty
	if events == nil {
		events = []EventResponse{}
	}

	json.NewEncoder(w).Encode(events)
}

// Delete channel handler
func (s *Server) DeleteChannel(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract channel UUID from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/protected/channels/")
	channelUuid := strings.TrimSuffix(path, "/delete")

	if channelUuid == "" || channelUuid == path {
		http.Error(w, "Channel UUID is required", http.StatusBadRequest)
		return
	}

	// Get user ID from context
	userID, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		http.Error(w, "Invalid user context", http.StatusInternalServerError)
		return
	}

	// Check if channel exists and user is the creator
	var channelID, createdBy int
	var channelName string

	err := s.db.QueryRow(`
		SELECT id, channel_name, created_by 
		FROM channels 
		WHERE channel_uuid = ?
	`, channelUuid).Scan(&channelID, &channelName, &createdBy)

	if err == sql.ErrNoRows {
		http.Error(w, "Channel not found", http.StatusNotFound)
		return
	}
	if err != nil {
		log.Printf("[ERR] Failed to query channel: %v", err)
		http.Error(w, "Failed to delete channel", http.StatusInternalServerError)
		return
	}

	// Check if user is the creator
	if createdBy != userID {
		http.Error(w, "Only the channel creator can delete this channel", http.StatusForbidden)
		return
	}

	// Delete the channel (CASCADE will handle related records)
	_, err = s.db.Exec(`DELETE FROM channels WHERE channel_uuid = ?`, channelUuid)
	if err != nil {
		log.Printf("[ERR] Failed to delete channel: %v", err)
		http.Error(w, "Failed to delete channel", http.StatusInternalServerError)
		return
	}

	log.Printf("[LOG] Channel '%s' (UUID: %s) deleted by user %d", channelName, channelUuid, userID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Channel deleted successfully",
	})
}

// Delete event handler
func (s *Server) DeleteEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Extract event UUID from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/protected/events/")
	eventUuid := strings.TrimSuffix(path, "/delete")

	if eventUuid == "" || eventUuid == path {
		http.Error(w, "Event UUID is required", http.StatusBadRequest)
		return
	}

	// Get user ID from context
	userID, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		http.Error(w, "Invalid user context", http.StatusInternalServerError)
		return
	}

	// Check if event exists and user is the organizer
	var eventID, organiserUserID int
	var eventName string

	err := s.db.QueryRow(`
		SELECT id, event_name, organiser_user_id 
		FROM events 
		WHERE event_uuid = ?
	`, eventUuid).Scan(&eventID, &eventName, &organiserUserID)

	if err == sql.ErrNoRows {
		http.Error(w, "Event not found", http.StatusNotFound)
		return
	}
	if err != nil {
		log.Printf("[ERR] Failed to query event: %v", err)
		http.Error(w, "Failed to delete event", http.StatusInternalServerError)
		return
	}

	// Check if user is the organizer
	if organiserUserID != userID {
		http.Error(w, "Only the event organizer can delete this event", http.StatusForbidden)
		return
	}

	// Delete the event (CASCADE will handle related records)
	_, err = s.db.Exec(`DELETE FROM events WHERE event_uuid = ?`, eventUuid)
	if err != nil {
		log.Printf("[ERR] Failed to delete event: %v", err)
		http.Error(w, "Failed to delete event", http.StatusInternalServerError)
		return
	}

	log.Printf("[LOG] Event '%s' (UUID: %s) deleted by user %d", eventName, eventUuid, userID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Event deleted successfully",
	})
}

// Cleanup routine for expired tokens and rate limits
func (s *Server) startCleanupRoutine() {
	ticker := time.NewTicker(time.Hour)
	go func() {
		for range ticker.C {
			// Clean expired blacklisted tokens
			jwtBlacklist.Cleanup()

			// Clean expired rate limit entries
			authRateLimiter.Cleanup()

			log.Printf("[CLEANUP] Expired tokens and rate limits cleaned up")
		}
	}()
}
