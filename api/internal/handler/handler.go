package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/ogen-go/ogen/ogenerrors"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"
	"task-manager/api/internal/websocket"
)

// Handler implements api.Handler.
type Handler struct {
	pool               *pgxpool.Pool
	q                  *repository.Queries
	jwt                *auth.JWTService
	hub                websocket.Hub
	googleClientID     string
	googleClientSecret string
}

func New(pool *pgxpool.Pool, q *repository.Queries, jwt *auth.JWTService, hub websocket.Hub, googleClientID, googleClientSecret string) *Handler {
	return &Handler{pool: pool, q: q, jwt: jwt, hub: hub, googleClientID: googleClientID, googleClientSecret: googleClientSecret}
}

// NewError converts an error returned by a handler method into the ogen error response.
func (h *Handler) NewError(_ context.Context, err error) *api.ApiErrorStatusCode {
	code := http.StatusInternalServerError
	var statusErr *statusError
	var secErr *ogenerrors.SecurityError
	if errors.As(err, &statusErr) {
		code = statusErr.code
	} else if errors.As(err, &secErr) {
		code = http.StatusUnauthorized
	}
	return &api.ApiErrorStatusCode{
		StatusCode: code,
		Response: api.ApiError{
			Code:    int32(code),
			Message: err.Error(),
		},
	}
}

// statusError wraps an error with an HTTP status code.
type statusError struct {
	code int
	err  error
}

func (e *statusError) Error() string { return e.err.Error() }
func (e *statusError) Unwrap() error { return e.err }

func errNotFound(msg string) error {
	return &statusError{code: http.StatusNotFound, err: errors.New(msg)}
}

func errBadRequest(msg string) error {
	return &statusError{code: http.StatusBadRequest, err: errors.New(msg)}
}

func errUnauthorized(msg string) error {
	return &statusError{code: http.StatusUnauthorized, err: errors.New(msg)}
}

func errConflict(msg string) error {
	return &statusError{code: http.StatusConflict, err: errors.New(msg)}
}
