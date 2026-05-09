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

type TaskParams struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	Title      string
	StatusID   uuid.UUID
	Importance int32
	Urgency    int32
	Memo       *string
	DueDate    pgtype.Timestamptz
	CreatedAt  pgtype.Timestamptz
	UpdatedAt  pgtype.Timestamptz
}

func CreateTask(t *testing.T, pool *pgxpool.Pool, p TaskParams) repository.Task {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreateTask: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Title == "" {
		p.Title = "Test Task"
	}
	if p.Importance == 0 {
		p.Importance = 1
	}
	if p.Urgency == 0 {
		p.Urgency = 1
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	task, err := q.CreateTask(context.Background(), repository.CreateTaskParams{
		ID:         p.ID,
		UserID:     p.UserID,
		Title:      p.Title,
		StatusID:   p.StatusID,
		Importance: p.Importance,
		Urgency:    p.Urgency,
		Memo:       p.Memo,
		DueDate:    p.DueDate,
		CreatedAt:  p.CreatedAt,
		UpdatedAt:  p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateTask: %v", err)
	}
	return task
}
