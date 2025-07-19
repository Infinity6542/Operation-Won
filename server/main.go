package main

import (
	// "encoding/json"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

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
	if err = db.Ping(); err != nil {
		panic(err.Error())
	} else {
		log.Println("[LOG] [SRV] Connected to db")
	}

	if err := os.MkdirAll("./audio", os.ModePerm); err != nil {
		log.Fatalf("[DIR] [CRT] Failed to create audio directory: %s", err)
	}

	//* Start the hub and run it
	hub := NewHub(client)
	go hub.Start()

	server := NewServer(hub, db, client)	 

	//* Begin listening for HTTP connections to upgrade
	http.HandleFunc("/auth/login", server.HandleAuth)
	http.HandleFunc("/auth/register", server.HandleRegister)
	http.Handle("/channels/create", server.Security(http.HandlerFunc(server.CreateChannel)))
	http.Handle("/channels", server.Security(http.HandlerFunc(server.GetChannels)))
	http.HandleFunc("/msg", func (w http.ResponseWriter, r *http.Request) {
		server.ServeWs(hub, w, r)
	})
	http.ListenAndServe(":8000", nil)
	log.Println("[SVR] [CON] Server is now listening on port 8000")
}

