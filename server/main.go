package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

// Variables
var (
	upgrader = websocket.Upgrader{}
	db       *sql.DB
)

func main() {
	log.Println("Starting Operation Won Server...")

	// Load environment variables with defaults
	redisHost := getEnv("REDIS_HOST", "localhost")
	redisPort := getEnv("REDIS_PORT", "6379")
	mysqlHost := getEnv("MYSQL_HOST", "localhost")
	mysqlPort := getEnv("MYSQL_PORT", "3306")
	mysqlUser := getEnv("MYSQL_USER", "root")
	mysqlPassword := getEnv("MYSQL_PASSWORD", "yes")
	mysqlDatabase := getEnv("MYSQL_DATABASE", "opwon")
	serverPort := getEnv("SERVER_PORT", "8000")

	// Redis configuration
	redisAddr := fmt.Sprintf("%s:%s", redisHost, redisPort)
	log.Printf("[LOG] [SRV] Connecting to Redis at %s", redisAddr)

	client := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "", // No password set
		DB:       0,  // Use default DB
		Protocol: 2,  // Connection protocol
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
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s", mysqlUser, mysqlPassword, mysqlHost, mysqlPort, mysqlDatabase)
	log.Printf("[LOG] [SRV] Connecting to MySQL at %s:%s", mysqlHost, mysqlPort)

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

	// Authentication endpoints (no security middleware)
	http.HandleFunc("/auth/login", server.HandleAuth)
	http.HandleFunc("/auth/register", server.HandleRegister)
	
	// JWT management endpoints (require authentication)
	http.Handle("/api/refresh", server.Security(http.HandlerFunc(server.HandleRefreshToken)))
	http.Handle("/api/logout", server.Security(http.HandlerFunc(server.HandleLogout)))
	
	// Protected API endpoints
	http.Handle("/api/protected/channels/create", server.Security(http.HandlerFunc(server.CreateChannel)))
	http.Handle("/api/protected/channels", server.Security(http.HandlerFunc(server.GetChannels)))
	http.Handle("/api/protected/events/create", server.Security(http.HandlerFunc(server.CreateEvent)))
	http.Handle("/api/protected/events", server.Security(http.HandlerFunc(server.GetEvents)))
	
	// WebSocket endpoint (requires special handling)
	http.HandleFunc("/msg", func(w http.ResponseWriter, r *http.Request) {
		server.ServeWs(hub, w, r)
	})

	// Health check endpoint for Docker
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	log.Printf("[SVR] [CON] Server is now listening on port %s", serverPort)
	http.ListenAndServe(":"+serverPort, nil)
}
