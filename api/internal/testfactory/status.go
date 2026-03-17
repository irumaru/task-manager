package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type StatusParams struct {
	UserID       uuid.UUID
	Name         string
	DisplayOrder int32
}

func CreateStatus(t *testing.T, pool *pgxpool.Pool, p StatusParams) repository.Status {
	t.Helper()
	if p.Name == "" {
		p.Name = "Todo"
	}
	q := repository.New(pool)
	status, err := q.CreateStatus(context.Background(), repository.CreateStatusParams{
		UserID:       p.UserID,
		Name:         p.Name,
		DisplayOrder: p.DisplayOrder,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateStatus: %v", err)
	}
	return status
}
