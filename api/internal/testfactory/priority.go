package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PriorityParams struct {
	UserID       uuid.UUID
	Name         string
	DisplayOrder int32
}

func CreatePriority(t *testing.T, pool *pgxpool.Pool, p PriorityParams) repository.Priority {
	t.Helper()
	if p.Name == "" {
		p.Name = "Medium"
	}
	q := repository.New(pool)
	priority, err := q.CreatePriority(context.Background(), repository.CreatePriorityParams{
		UserID:       p.UserID,
		Name:         p.Name,
		DisplayOrder: p.DisplayOrder,
	})
	if err != nil {
		t.Fatalf("testfactory.CreatePriority: %v", err)
	}
	return priority
}
