package auth

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

type contextKey string

const claimsKey contextKey = "claims"

func WithClaims(ctx context.Context, claims *Claims) context.Context {
	return context.WithValue(ctx, claimsKey, claims)
}

func ClaimsFromContext(ctx context.Context) (*Claims, error) {
	c, ok := ctx.Value(claimsKey).(*Claims)
	if !ok || c == nil {
		return nil, errors.New("unauthenticated")
	}
	return c, nil
}

func UserIDFromContext(ctx context.Context) (uuid.UUID, error) {
	c, err := ClaimsFromContext(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	return c.UserID, nil
}
