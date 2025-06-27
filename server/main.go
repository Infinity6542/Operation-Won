package main

import (
	// "encoding/json"
	"context"
	"log"

	// "net/http"
	// "os"
	// "sync"
	// "time"
	"database/sql"

	// "github.com/gorilla/websocket"
	_ "github.com/go-sql-driver/mysql"
	"github.com/redis/go-redis/v9"
)

// Ok so I need to rewrite this entire thing basically
// After I finish the server I can start on the client
// But first the server and the design

// Please refer to the flowcharts to know what to name these things cos otherwise I will forget lol :)

// When will this thing refresh smh I need to get it now

// Upgrader for WebSocket connections with permissive CORS policy for easy testing

// 1. Make sure all services are running first (redis, DB, HTTP server) JSON signals as well
// 2. Wait for connection
// 3. Once connections are made, listen for messages (messages go through router)
// 4. If there is a new transmission, made new UUID, new file, new record and alert recipients
// 5. Run reading, writing and broadcasting (to UUID.e and distribute to clients)

func main() {
	log.Println("Starting up...")

	// TODO: Maybe change the entire startup process to check Podman first
	//* Connecting to and testing Redis
	log.Println("[LOG] [SRV] Connecting to Redis")
	client := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // No password set
		DB:       0,  // Use default DB
		Protocol: 2,  // Connection protocol
	})
	ctx := context.Background()
	err := client.Set(ctx, "foo", "bar", 0).Err()
	if err != nil {
		panic(err)
	}
	val, err := client.Get(ctx, "foo").Result()
	if err != nil {
		panic(err)
	}
	if val != "bar" {
		panic("Value mismatch: expected 'bar', got '" + val + "'")
	} else {
		log.Println("[LOG] [SRV] Connected to Redis")
	}
	client.Del(ctx, "foo").Result()

	//* Connecting to and testing MySQL
	log.Println("[LOG] [SRV] Connecting to db")
	dsn := "root:yes@tcp(10.88.0.20:3306)/"
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()
	// Verify the connection is valid
	err = db.Ping()
	if err != nil {
		panic(err.Error())
	} else {
		log.Println("[LOG] [SRV] Connected to db")
	}
}
