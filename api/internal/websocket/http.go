package websocket

import (
	"log"
	"net/http"

	"task-manager/api/internal/auth"
)

// ServeWS upgrades the HTTP connection to WebSocket and runs the client loop.
// It expects a valid JWT in the "token" query parameter.
func ServeWS(hub Hub, jwtSvc *auth.JWTService, w http.ResponseWriter, r *http.Request) {
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}

	claims, err := jwtSvc.Verify(tokenStr)
	if err != nil {
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws: upgrade error: %v", err)
		return
	}

	conn := NewConn(ws, hub, claims.UserID)
	go conn.Run()
}
