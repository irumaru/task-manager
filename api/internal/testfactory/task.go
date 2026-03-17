package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TaskParams struct {
	UserID     uuid.UUID
	Title      string
	StatusID   uuid.UUID
	PriorityID uuid.NullUUID
	Memo       *string
	DueDate    pgtype.Timestamptz
}

func CreateTask(t *testing.T, pool *pgxpool.Pool, p TaskParams) repository.Task {
	t.Helper()
	if p.Title == "" {
		p.Title = "Test Task"
	}
	q := repository.New(pool)
	task, err := q.CreateTask(context.Background(), repository.CreateTaskParams{
		UserID:     p.UserID,
		Title:      p.Title,
		StatusID:   p.StatusID,
		PriorityID: p.PriorityID,
		Memo:       p.Memo,
		DueDate:    p.DueDate,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateTask: %v", err)
	}
	return task
}
