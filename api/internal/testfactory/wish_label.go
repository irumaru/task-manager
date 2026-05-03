package testfactory

import (
	"context"
	"testing"
	"time"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WishLabelParams struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Name      string
	CreatedAt pgtype.Timestamptz
	UpdatedAt pgtype.Timestamptz
}

func CreateWishLabel(t *testing.T, pool *pgxpool.Pool, p WishLabelParams) repository.WishLabel {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreateWishLabel: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Name == "" {
		p.Name = "test-wish-label"
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	label, err := q.CreateWishLabel(context.Background(), repository.CreateWishLabelParams{
		ID:        p.ID,
		UserID:    p.UserID,
		Name:      p.Name,
		CreatedAt: p.CreatedAt,
		UpdatedAt: p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateWishLabel: %v", err)
	}
	return label
}
