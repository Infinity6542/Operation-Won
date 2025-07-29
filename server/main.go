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
	log.Println("Starting up...")

	// TODO: Maybe change the entire startup process to check Podman first
	// Connecting to and testing Redis
	log.Println("[LOG] [SRV] Connecting to Redis")
	client := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // No password set
		DB:       0,  // Use default DB
		Protocol: 2,  // Connection protocol
	})

	ctx := context.Background()
	e := client.Set(ctx, "foo", "bar", 0).Err()
	if e != nil {
		panic(e)
	}

	val, e := client.Get(ctx, "foo").Result()
	if e != nil {
		panic(e)
	}
	if val != "bar" {
		panic("Value mismatch: expected 'bar', got '" + val + "'")
	} else {
		log.Println("[LOG] [SRV] Connected to Redis")
	}
	client.Del(ctx, "foo").Result()

	// Connecting to and testing MySQL
	var dbip string
	log.Println("[LOG] [SRV] Connecting to db")
	fmt.Print("Enter the internal IP address of the mySQL database:")
	fmt.Scan(&dbip)

	var e2 error
	dsn := "root:yes@tcp(" + dbip + ":3306)/opwon"
	db, e2 = sql.Open("mysql", dsn)
	if e2 != nil {
		panic(e2.Error())
	}

	// Verify the connection is valid
	if e = db.Ping(); e != nil {
		panic(e.Error())
	} else {
		log.Println("[LOG] [SRV] Connected to db")
	}

	if e := os.MkdirAll("./audio", os.ModePerm); e != nil {
		log.Fatalf("[DIR] [CRT] Failed to create audio directory: %s", e)
	}

	// Start the hub and run it
	hub := NewHub(client)
	go hub.Start()

	server := NewServer(hub, db, client)

	// Begin listening for HTTP connections to upgrade
	http.HandleFunc("/auth/login", server.HandleAuth)
	http.HandleFunc("/auth/register", server.HandleRegister)
	http.Handle("/channels/create", server.Security(http.HandlerFunc(server.CreateChannel)))
	http.Handle("/channels", server.Security(http.HandlerFunc(server.GetChannels)))
	http.Handle("/events/create", server.Security(http.HandlerFunc(server.CreateEvent)))
	http.Handle("/events", server.Security(http.HandlerFunc(server.GetEvents)))
	http.HandleFunc("/msg", func(w http.ResponseWriter, r *http.Request) {
		server.ServeWs(hub, w, r)
	})

	log.Println("[SVR] [CON] Server is now listening on port 8000")
	http.ListenAndServe(":8000", nil)
}
