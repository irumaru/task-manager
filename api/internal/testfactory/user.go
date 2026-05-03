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

type UserParams struct {
	ID          uuid.UUID
	Email       string
	DisplayName string
	AvatarUrl   *string
	CreatedAt   pgtype.Timestamptz
	UpdatedAt   pgtype.Timestamptz
}

func CreateUser(t *testing.T, pool *pgxpool.Pool, p UserParams) repository.User {
	t.Helper()
	if p.ID == uuid.Nil {
		id, err := uuid.NewV7()
		if err != nil {
			t.Fatalf("testfactory.CreateUser: uuid.NewV7: %v", err)
		}
		p.ID = id
	}
	if p.Email == "" {
		p.Email = "test@example.com"
	}
	if p.DisplayName == "" {
		p.DisplayName = "Test User"
	}
	if !p.CreatedAt.Valid {
		p.CreatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	if !p.UpdatedAt.Valid {
		p.UpdatedAt = pgtype.Timestamptz{Time: time.Now(), Valid: true}
	}
	q := repository.New(pool)
	user, err := q.UpsertUser(context.Background(), repository.UpsertUserParams{
		ID:          p.ID,
		Email:       p.Email,
		DisplayName: p.DisplayName,
		AvatarUrl:   p.AvatarUrl,
		CreatedAt:   p.CreatedAt,
		UpdatedAt:   p.UpdatedAt,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateUser: %v", err)
	}
	return user
}
