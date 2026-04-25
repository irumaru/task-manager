package auth

import (
	"context"
	"errors"
	"log/slog"

	"task-manager/api/internal/api"
)

// SecurityHandler implements api.SecurityHandler.
type SecurityHandler struct {
	jwt *JWTService
}

func NewSecurityHandler(jwt *JWTService) *SecurityHandler {
	return &SecurityHandler{jwt: jwt}
}

func (s *SecurityHandler) HandleBearerAuth(ctx context.Context, _ api.OperationName, t api.BearerAuth) (context.Context, error) {
	claims, err := s.jwt.Verify(t.Token)
	if err != nil {
		slog.DebugContext(ctx, "failed to verify JWT token", "err", err)
		return ctx, errors.New("invalid or expired token")
	}
	return WithClaims(ctx, claims), nil
}
