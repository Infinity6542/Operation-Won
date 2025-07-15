package main

import (
	// "encoding/json"
	"context"
	"fmt"
	"log"
	"net/http"

	// "fmt"
	// "os"
	// "sync"
	// "time"
	"database/sql"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

// Ok so I need to rewrite this entire thing basically
// After I finish the server I can start on the client
// But first the server and the design

// 1. Make sure all services are running first (redis, DB, HTTP server) JSON signals as well
// 2. Wait for connection
// 3. Once connections are made, listen for messages (messages go through router)
// 4. If there is a new transmission, made new UUID, new file, new record and alert recipients
// 5. Run reading, writing and broadcasting (to UUID.e and distribute to clients)

//* Variables
var upgrader = websocket.Upgrader{}
var db *sql.DB

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
	var dbip string

	log.Println("[LOG] [SRV] Connecting to db")
	fmt.Print("Enter the internal IP address of the mySQL database:")
	fmt.Scan(&dbip)
	var erro error
	dsn := "root:yes@tcp(" + dbip + ":3306)/opwon"
	db, erro = sql.Open("mysql", dsn)
	if erro != nil {
		panic(erro.Error())
	}
	// Verify the connection is valid
	err = db.Ping()
	if err != nil {
		panic(err.Error())
	} else {
		log.Println("[LOG] [SRV] Connected to db")
	}

	//* Begin listening for HTTP connections to upgrade
	http.HandleFunc("/auth/login", HandleAuth)
	http.HandleFunc("/auth/register", HandleRegister)
	http.HandleFunc("/msg", router)
	http.ListenAndServe(":8000", nil)
}

func router(w http.ResponseWriter, r *http.Request) {
	// TODO: Rewrite this to play better with hub
	log.Println("[LOG] [SRV] Received HTTP request")
	connection, err := upgrader.Upgrade(w, r, nil)

	if err != nil {
		log.Printf("[ERR] [SRV] Error upgrading connection: %v", err)
		http.Error(w, "Could not upgrade connection", http.StatusInternalServerError)
		return
	} else {
		log.Println("[LOG] [SRV] Upgraded HTTP connection to WebSocket")
	}

	for {
		mtype, message, err := connection.ReadMessage()
		log.Println("[LOG] [SRV] Read message from WebSocket")
		log.Println(mtype)

		if mtype == websocket.CloseMessage {
			log.Println("[LOG] [SRV] Connection closed")
			break
		} else if err != nil {
			log.Printf("[ERR] [SRV] Error reading message: %v", err)
			break
		} else {
			switch mtype {
			case websocket.TextMessage:
				go handleSignal(message)
			case websocket.BinaryMessage:
				go handleBinary(message)
			}
			log.Printf("[LOG] [SRV] Received message: %s", message)
		}
	}
	connection.Close()
}

func handleSignal(message []byte) {
	log.Printf("[LOG] [SRV] Handling signal: %s", message)
	// Here you would handle the signal, e.g., parse it, store it, etc.
	// For now, just log it
	// You can also implement logic to handle different types of signals
	// and perform actions based on the content of the message.

}

func handleBinary(message []byte) {
	log.Printf("[LOG] [SRV] Handling binary: %s", message)
	// Here you would handle the signal, e.g., parse it, store it, etc.
	// For now, just log it
	// You can also implement logic to handle different types of signals
	// and perform actions based on the content of the message.
}
