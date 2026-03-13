package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	gorilla "github.com/gorilla/websocket"
)

const (
	writeTimeout = 10 * time.Second
	pongTimeout  = 60 * time.Second
	pingInterval = (pongTimeout * 9) / 10
	maxMessage   = 512
)

var upgrader = gorilla.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

// Conn wraps a gorilla WebSocket connection and implements Client.
type Conn struct {
	ws     *gorilla.Conn
	send   chan Event
	hub    Hub
	userID uuid.UUID
}

func NewConn(ws *gorilla.Conn, hub Hub, userID uuid.UUID) *Conn {
	return &Conn{
		ws:     ws,
		send:   make(chan Event, 64),
		hub:    hub,
		userID: userID,
	}
}

func (c *Conn) Send(event Event) {
	select {
	case c.send <- event:
	default:
		log.Printf("ws: send buffer full for user %s, dropping event", c.userID)
	}
}

// Run starts the read and write pumps. Blocks until the connection closes.
func (c *Conn) Run() {
	c.hub.Register(c.userID, c)
	defer func() {
		c.hub.Unregister(c.userID, c)
		c.ws.Close()
	}()

	go c.writePump()
	c.readPump()
}

func (c *Conn) readPump() {
	c.ws.SetReadLimit(maxMessage)
	_ = c.ws.SetReadDeadline(time.Now().Add(pongTimeout))
	c.ws.SetPongHandler(func(string) error {
		return c.ws.SetReadDeadline(time.Now().Add(pongTimeout))
	})
	for {
		_, _, err := c.ws.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (c *Conn) writePump() {
	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()

	for {
		select {
		case event, ok := <-c.send:
			_ = c.ws.SetWriteDeadline(time.Now().Add(writeTimeout))
			if !ok {
				_ = c.ws.WriteMessage(gorilla.CloseMessage, []byte{})
				return
			}
			b, err := json.Marshal(event)
			if err != nil {
				log.Printf("ws: marshal error: %v", err)
				continue
			}
			if err := c.ws.WriteMessage(gorilla.TextMessage, b); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.ws.SetWriteDeadline(time.Now().Add(writeTimeout))
			if err := c.ws.WriteMessage(gorilla.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
