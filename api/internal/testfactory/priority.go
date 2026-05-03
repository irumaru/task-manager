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

type PriorityParams struct {
	ID           uuid.UUID
	UserID       uuid.UUID
	Name         string
	DisplayOrder int32
	CreatedAt    pgtype.Timestamptz
	UpdatedAt    pgtype.Timestamptz
}

func CreatePriority(t *testing.T, pool *pgxpool.Pool, p PriorityParams) repository.Priority {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreatePriority: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Name == "" {
		p.Name = "Medium"
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	priority, err := q.CreatePriority(context.Background(), repository.CreatePriorityParams{
		ID:           p.ID,
		UserID:       p.UserID,
		Name:         p.Name,
		DisplayOrder: p.DisplayOrder,
		CreatedAt:    p.CreatedAt,
		UpdatedAt:    p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreatePriority: %v", err)
	}
	return priority
}
