package main

// temporarily set to main for testing

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

type handler struct {
	upgrader websocket.Upgrader
}

func (wsh handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	c, err := wsh.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Error upgrading connection: %v", err)
		return
	}
	defer c.Close()

	for {
		mt, message, err := c.ReadMessage()
		if err != nil {
			log.Printf("Error reading message: %v", err)
			return
		}
		if mt == websocket.BinaryMessage {
			err = c.WriteMessage(websocket.TextMessage, []byte("The server doesn't support binary messages!"))
			if err != nil {
				log.Printf("Error writing message: %v", err)
			}
			return
		}
		log.Printf("Received message: %s", string(message))
		received := strings.Trim(string(message), "\n")
		switch received {
		case "ping":
			log.Println("Received ping, sending pong...")

		case "start":
			log.Println("Start responding to client...")
			var i int = 1
			for {
				response := fmt.Sprintf("Response %d", i)
				err = c.WriteMessage(websocket.TextMessage, []byte(response))
				if err != nil {
					log.Printf("Error sending message: %v", err)
					return
				}
				i = i + 1
				time.Sleep(2 * time.Second)
			}
		case "stop":
			log.Println("Received stop, stopping...")
			err = c.WriteMessage(websocket.TextMessage, []byte("Stopping..."))
			if err != nil {
				log.Printf("Error sending message: %v", err)
				return
			}
		case "disconnect":
			log.Println("Received disconnect, disconnecting...")
			err = c.WriteMessage(websocket.TextMessage, []byte("Disconnecting..."))
			if err != nil {
				log.Printf("Error sending message: %v", err)
				return
			}
			defer func() {
				log.Println("Closing connection to client...")
				defer c.Close()
			}()
		default:
			log.Printf("Received unknown command: %s", received)
			err = c.WriteMessage(websocket.TextMessage, []byte("Unknown command!"))
		}
	}
}

func main() {
	handler := handler{
		upgrader: websocket.Upgrader{},
	}
	http.Handle("/", handler)
	log.Print("Starting server")
	log.Fatal(http.ListenAndServe("localhost:8080", nil))
}
