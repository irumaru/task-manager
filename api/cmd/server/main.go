package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/bootstrap"
	"task-manager/api/internal/handler"
	"task-manager/api/internal/repository"
	ws "task-manager/api/internal/websocket"
)

func main() {
	ctx := context.Background()

	// -----------------------------------------------------------------------
	// Config from environment
	// -----------------------------------------------------------------------
	dbURL := mustEnv("DATABASE_URL")
	jwtSecret := mustEnv("JWT_SECRET")
	googleClientID := mustEnv("GOOGLE_CLIENT_ID")
	googleClientSecret := mustEnv("GOOGLE_CLIENT_SECRET")
	port := envOr("PORT", "8080")

	// -----------------------------------------------------------------------
	// Database
	// -----------------------------------------------------------------------
	pool, err := bootstrap.SetupDatabase(ctx, dbURL)
	if err != nil {
		log.Fatalf("db: bootstrap: %v", err)
	}
	defer pool.Close()

	q := repository.New(pool)

	// -----------------------------------------------------------------------
	// Services
	// -----------------------------------------------------------------------
	jwtSvc := auth.NewJWTService(jwtSecret)
	hub := ws.NewLocalHub()

	// -----------------------------------------------------------------------
	// HTTP handlers (ogen)
	// -----------------------------------------------------------------------
	h := handler.New(q, jwtSvc, hub, googleClientID, googleClientSecret)
	sec := auth.NewSecurityHandler(jwtSvc)

	srv, err := api.NewServer(h, sec)
	if err != nil {
		log.Fatalf("ogen: new server: %v", err)
	}

	// -----------------------------------------------------------------------
	// HTTP mux
	// -----------------------------------------------------------------------
	mux := http.NewServeMux()
	mux.Handle("/", loggingMiddleware(srv))
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ws.ServeWS(hub, jwtSvc, w, r)
	})

	log.Printf("listening on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatalf("http: %v", err)
	}
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rw, r)
		log.Printf("%s %s %d %s", r.Method, r.URL.Path, rw.status, time.Since(start))
	})
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("env %s is required", key)
	}
	return v
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
