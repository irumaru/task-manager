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

type WishParams struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Title     string
	Detail    *string
	CreatedAt pgtype.Timestamptz
	UpdatedAt pgtype.Timestamptz
}

func CreateWish(t *testing.T, pool *pgxpool.Pool, p WishParams) repository.Wish {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreateWish: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Title == "" {
		p.Title = "test wish"
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	wish, err := q.CreateWish(context.Background(), repository.CreateWishParams{
		ID:        p.ID,
		UserID:    p.UserID,
		Title:     p.Title,
		Detail:    p.Detail,
		CreatedAt: p.CreatedAt,
		UpdatedAt: p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateWish: %v", err)
	}
	return wish
}
