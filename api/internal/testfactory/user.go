package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/jackc/pgx/v5/pgxpool"
)

type UserParams struct {
	Email       string
	DisplayName string
	AvatarUrl   *string
}

func CreateUser(t *testing.T, pool *pgxpool.Pool, p UserParams) repository.User {
	t.Helper()
	if p.Email == "" {
		p.Email = "test@example.com"
	}
	if p.DisplayName == "" {
		p.DisplayName = "Test User"
	}
	q := repository.New(pool)
	user, err := q.UpsertUser(context.Background(), repository.UpsertUserParams{
		Email:       p.Email,
		DisplayName: p.DisplayName,
		AvatarUrl:   p.AvatarUrl,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateUser: %v", err)
	}
	return user
}
