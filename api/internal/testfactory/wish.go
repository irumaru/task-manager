package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WishParams struct {
	UserID uuid.UUID
	Title  string
	Detail *string
}

func CreateWish(t *testing.T, pool *pgxpool.Pool, p WishParams) repository.Wish {
	t.Helper()
	if p.Title == "" {
		p.Title = "test wish"
	}
	q := repository.New(pool)
	wish, err := q.CreateWish(context.Background(), repository.CreateWishParams{
		UserID: p.UserID,
		Title:  p.Title,
		Detail: p.Detail,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateWish: %v", err)
	}
	return wish
}
