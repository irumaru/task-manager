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

type StatusParams struct {
	ID           uuid.UUID
	UserID       uuid.UUID
	Name         string
	DisplayOrder int32
	CreatedAt    pgtype.Timestamptz
	UpdatedAt    pgtype.Timestamptz
}

func CreateStatus(t *testing.T, pool *pgxpool.Pool, p StatusParams) repository.Status {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreateStatus: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Name == "" {
		p.Name = "Todo"
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	status, err := q.CreateStatus(context.Background(), repository.CreateStatusParams{
		ID:           p.ID,
		UserID:       p.UserID,
		Name:         p.Name,
		DisplayOrder: p.DisplayOrder,
		CreatedAt:    p.CreatedAt,
		UpdatedAt:    p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateStatus: %v", err)
	}
	return status
}
