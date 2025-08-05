package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

// Variables
var (
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true // Allow connections from any origin
		},
	}
	db *sql.DB
)

func main() {
	log.Println("Starting Operation Won Server...")

	// Load environment variables with defaults
	redisHost := getEnv("REDIS_HOST", "opwon_redis")
	redisPort := getEnv("REDIS_PORT", "6379")
	mysqlHost := getEnv("MYSQL_HOST", "opwon_mysql") // Use service name by default for Docker
	mysqlPort := getEnv("MYSQL_PORT", "3306")
	mysqlUser := getEnv("MYSQL_USER", "opwon_user")
	mysqlPassword := getEnv("MYSQL_PASSWORD", "opwon_password")
	mysqlDatabase := getEnv("MYSQL_DATABASE", "operation_won")
	serverPort := getEnv("SERVER_PORT", "8000")

	// Redis configuration
	redisAddr := fmt.Sprintf("%s:%s", redisHost, redisPort)
	log.Printf("[LOG] [SRV] Connecting to Redis at %s", redisAddr)

	client := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "", // No password set
		DB:       0,  // Use default DB
		Protocol: 2,  // Connection protocol

		// Connection pool optimization
		PoolSize:        10,                     // Maximum number of socket connections
		PoolTimeout:     30 * time.Second,       // Amount of time client waits for connection
		ConnMaxIdleTime: 5 * time.Minute,        // Amount of time after which client closes idle connections
		MaxRetries:      3,                      // Maximum number of retries before giving up
		MinRetryBackoff: 8 * time.Millisecond,   // Minimum backoff between each retry
		MaxRetryBackoff: 512 * time.Millisecond, // Maximum backoff between each retry
	})

	ctx := context.Background()
	e := client.Set(ctx, "foo", "bar", 0).Err()
	if e != nil {
		log.Printf("[ERR] [SRV] Failed to connect to Redis: %v", e)
		panic(e)
	}

	val, e := client.Get(ctx, "foo").Result()
	if e != nil {
		log.Printf("[ERR] [SRV] Failed to test Redis: %v", e)
		panic(e)
	}
	if val != "bar" {
		panic("Value mismatch: expected 'bar', got '" + val + "'")
	} else {
		log.Println("[LOG] [SRV] Connected to Redis")
	}
	client.Del(ctx, "foo").Result()

	// MySQL configuration
	log.Printf("[LOG] [SRV] Connecting to MySQL at %s:%s", mysqlHost, mysqlPort)
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s", mysqlUser, mysqlPassword, mysqlHost, mysqlPort, mysqlDatabase)

	var e2 error
	db, e2 = sql.Open("mysql", dsn)
	if e2 != nil {
		log.Printf("[ERR] [SRV] Failed to open MySQL connection: %v", e2)
		panic(e2.Error())
	}

	// Verify the connection is valid
	if e := db.Ping(); e != nil {
		log.Printf("[ERR] [SRV] Failed to ping MySQL: %v", e)
		panic(e.Error())
	} else {
		log.Println("[LOG] [SRV] Connected to MySQL")
	}

	if e := os.MkdirAll("./audio", os.ModePerm); e != nil {
		log.Fatalf("[DIR] [CRT] Failed to create audio directory: %s", e)
	}

	// Start the hub and run it
	hub := NewHub(client)
	go hub.Start()

	server := NewServer(hub, db, client)

	// Start cleanup routine for JWT blacklist and rate limiting
	server.startCleanupRoutine()

	// CORS middleware for Flutter app
	corsHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			log.Printf("[DEBUG] Incoming request: %s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

			if r.Method == "OPTIONS" {
				log.Printf("[DEBUG] Handling OPTIONS preflight request")
				w.WriteHeader(http.StatusOK)
				return
			}

			next.ServeHTTP(w, r)
		})
	}

	// Authentication endpoints (no security middleware but with CORS)
	http.Handle("/auth/login", corsHandler(http.HandlerFunc(server.HandleAuth)))
	http.Handle("/auth/register", corsHandler(http.HandlerFunc(server.HandleRegister)))

	// JWT management endpoints (require authentication)
	http.Handle("/api/refresh", corsHandler(server.Security(http.HandlerFunc(server.HandleRefreshToken))))
	http.Handle("/api/logout", corsHandler(server.Security(http.HandlerFunc(server.HandleLogout))))

	// Protected API endpoints
	http.Handle("/api/protected/channels/create", corsHandler(server.Security(http.HandlerFunc(server.CreateChannel))))
	http.Handle("/api/protected/channels", corsHandler(server.Security(http.HandlerFunc(server.GetChannels))))
	http.Handle("/api/protected/events/create", corsHandler(server.Security(http.HandlerFunc(server.CreateEvent))))
	http.Handle("/api/protected/events/join", corsHandler(server.Security(http.HandlerFunc(server.JoinEvent))))
	http.Handle("/api/protected/events", corsHandler(server.Security(http.HandlerFunc(server.GetEvents))))

	// Delete endpoints
	http.HandleFunc("/api/protected/channels/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/delete") {
			if r.Method == http.MethodDelete || r.Method == http.MethodOptions {
				corsHandler(server.Security(http.HandlerFunc(server.DeleteChannel))).ServeHTTP(w, r)
			} else {
				http.NotFound(w, r)
			}
		} else {
			http.NotFound(w, r)
		}
	})
	// Event delete handler with specific pattern
	http.HandleFunc("/api/protected/events/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("[DEBUG] Events handler called: %s %s", r.Method, r.URL.Path)
		if strings.HasSuffix(r.URL.Path, "/delete") {
			log.Printf("[DEBUG] Delete path matched, method: %s", r.Method)
			if r.Method == http.MethodDelete || r.Method == http.MethodOptions {
				corsHandler(server.Security(http.HandlerFunc(server.DeleteEvent))).ServeHTTP(w, r)
			} else {
				http.NotFound(w, r)
			}
		} else {
			log.Printf("[DEBUG] Path does not end with /delete: %s", r.URL.Path)
			http.NotFound(w, r)
		}
	})

	// Add global OPTIONS handler as fallback
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "OPTIONS" {
			log.Printf("[DEBUG] Global OPTIONS handler for: %s", r.URL.Path)
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			w.WriteHeader(http.StatusOK)
			return
		}
		http.NotFound(w, r)
	})

	// WebSocket endpoint (requires special handling)
	http.Handle("/msg", corsHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		server.ServeWs(hub, w, r)
	})))

	// Health check endpoint for Docker
	http.Handle("/health", corsHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})))

	log.Printf("[SVR] [CON] Server is now listening on port %s", serverPort)
	http.ListenAndServe(":"+serverPort, nil)
}
