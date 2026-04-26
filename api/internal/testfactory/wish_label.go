package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WishLabelParams struct {
	UserID uuid.UUID
	Name   string
}

func CreateWishLabel(t *testing.T, pool *pgxpool.Pool, p WishLabelParams) repository.WishLabel {
	t.Helper()
	if p.Name == "" {
		p.Name = "test-wish-label"
	}
	q := repository.New(pool)
	label, err := q.CreateWishLabel(context.Background(), repository.CreateWishLabelParams{
		UserID: p.UserID,
		Name:   p.Name,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateWishLabel: %v", err)
	}
	return label
}
