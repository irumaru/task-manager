package websocket

import (
	"sync"

	"github.com/google/uuid"
)

// LocalHub is a single-server in-process Hub implementation.
type LocalHub struct {
	mu      sync.RWMutex
	clients map[uuid.UUID]map[Client]struct{}
}

func NewLocalHub() *LocalHub {
	return &LocalHub{
		clients: make(map[uuid.UUID]map[Client]struct{}),
	}
}

func (h *LocalHub) Register(userID uuid.UUID, c Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.clients[userID]; !ok {
		h.clients[userID] = make(map[Client]struct{})
	}
	h.clients[userID][c] = struct{}{}
}

func (h *LocalHub) Unregister(userID uuid.UUID, c Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if conns, ok := h.clients[userID]; ok {
		delete(conns, c)
		if len(conns) == 0 {
			delete(h.clients, userID)
		}
	}
}

func (h *LocalHub) Broadcast(userID uuid.UUID, event Event) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	for c := range h.clients[userID] {
		c.Send(event)
	}
}
