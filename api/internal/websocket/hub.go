package websocket

import "github.com/google/uuid"

// Event is a JSON-serializable message broadcast to connected clients.
type Event struct {
	Type    string `json:"type"`
	Payload any    `json:"payload"`
}

// Hub manages WebSocket connections and broadcasts events to users.
type Hub interface {
	// Register adds a client connection for a given user.
	Register(userID uuid.UUID, client Client)
	// Unregister removes a client connection.
	Unregister(userID uuid.UUID, client Client)
	// Broadcast sends an event to all connections of the given user.
	Broadcast(userID uuid.UUID, event Event)
}

// Client represents a single WebSocket connection.
type Client interface {
	Send(event Event)
}
