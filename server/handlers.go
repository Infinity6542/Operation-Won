package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/go-sql-driver/mysql"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
)

var secret = []byte("verymuchasecr3t")

// Define a custom type for context keys to avoid collisions
type contextKey string

const userIDKey contextKey = "userID"

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

	var hash string
	var uid int
	var username string
	if e := s.db.QueryRow("SELECT id, username, hashed_password FROM users WHERE email = ?", payload.Email).Scan(&uid, &username, &hash); e != nil {
		if e == sql.ErrNoRows {
			http.Error(w, "Invalid credentials.", http.StatusUnauthorized)
			return
		}
		fmt.Printf("[AUT] [LGN] Something went wrong when searching for the user: %v\n", e)
		http.Error(w, "Invalid username.", http.StatusUnauthorized)
		return
	}

	auth := bcrypt.CompareHashAndPassword([]byte(hash), []byte(payload.Password))
	if auth != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		fmt.Printf("[AUT] [LGN] Incorrect password for user %s\n", username)
		return
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id":  uid,
		"username": username,
		"exp":      time.Now().Add(time.Hour * 48).Unix(),
	})

	tokenString, e := token.SignedString(secret)
	if e != nil {
		log.Printf("[AUT] [TKN] Failed to create a token: %s", e)
		http.Error(w, "Failed to create the token.", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{"token": tokenString})
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
	}

	claims := &jwt.MapClaims{}
	token, e := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return secret, nil
	})
	if e != nil || !token.Valid {
		http.Error(w, "Invalid token.", http.StatusUnauthorized)
		return
	}

	uidFloat, _ := (*claims)["user_id"].(float64)
	uid := int(uidFloat)

	channelID := r.URL.Query().Get("channel")
	if channelID == "" {
		http.Error(w, "Invalid Channel ID.", http.StatusBadRequest)
		return
	}

	conn, e := upgrader.Upgrade(w, r, nil)
	if e != nil {
		log.Printf("[WBS] [UPG] Error while upgrading HTTP to WebSockets: %s", e)
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
		authHeader := r.Header.Get("auth")
		if authHeader == "" {
			http.Error(w, "Invalid authentication.", http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			http.Error(w, "Invalid token format.", http.StatusUnauthorized)
		}

		claims := &jwt.MapClaims{}
		token, e := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return secret, nil
		})
		if e != nil || !token.Valid {
			http.Error(w, "Something went wrong with the authorisation token.", http.StatusUnauthorized)
		}

		uidFloat, _ := (*claims)["user_id"].(float64)
		ctx := context.WithValue(r.Context(), userIDKey, int(uidFloat))
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *Server) CreateChannel(w http.ResponseWriter, r *http.Request) {
	uid, ok := r.Context().Value(userIDKey).(int)
	if !ok {
		http.Error(w, "Failed to find user.", http.StatusInternalServerError)
		return
	}

	var payload CrtChannel
	if e := json.NewDecoder(r.Body).Decode(&payload); e != nil {
		http.Error(w, "Invalid request.", http.StatusBadRequest)
		return
	}
	if payload.ChannelName == "" {
		http.Error(w, "Channel name is required.", http.StatusBadRequest)
		return
	}

	var channelUUID = uuid.New().String()
	var lastInsertID int64

	tx, e := s.db.Begin()
	if e != nil {
		http.Error(w, "Database error.", http.StatusInternalServerError)
		return
	}

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

		_, e = tx.Exec("INSERT INTO channels (channel_uuid, channel_name, event_id) VALUES (?, ?, ?)",
			channelUUID, payload.ChannelName, eventID)
		if e != nil {
			tx.Rollback()
			http.Error(w, "Failed to create channel.", http.StatusInternalServerError)
			return
		}

	} else { // No event
		res, e := tx.Exec("INSERT INTO channels (channel_uuid, channel_name, event_id) VALUES (?, ?, NULL)",
			channelUUID, payload.ChannelName)
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
	}

	if e := tx.Commit(); e != nil {
		http.Error(w, "Failed to create channel.", http.StatusInternalServerError)
		return
	}

	log.Printf("[CHN] [CRT] %d created channel %s", uid, payload.ChannelName)

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Channel created successfully", "channel_uuid": channelUUID})
}

func (s *Server) GetChannels(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	uid, _ := r.Context().Value(userIDKey).(int)

	query := `SELECT c.channel_uuid, c.channel_name, e.event_uuid FROM channels c LEFT JOIN events e ON c.event_id = e.id LEFT JOIN event_members em ON e.id = em.event.id LEFT JOIN channel_members cm ON c.id = cm.channel_id WHERE em.user_id = ? OR cm.user_id = ?`

	rows, e := s.db.Query(query, uid, uid)
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
		if e := rows.Scan(&ch.ChannelUUID, &ch.ChannelName, &eventUUID); e != nil {
			log.Printf("[CHN] [DTB] Failed to scan channel row: %v", e)
			continue
		}
		if eventUUID.Valid {
			ch.EventUUID = &eventUUID.String
		}
		channels = append(channels, ch)
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

	json.NewEncoder(w).Encode(events)
}
