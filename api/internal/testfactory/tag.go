package testfactory

import (
	"context"
	"testing"

	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TagParams struct {
	UserID uuid.UUID
	Name   string
}

func CreateTag(t *testing.T, pool *pgxpool.Pool, p TagParams) repository.Tag {
	t.Helper()
	if p.Name == "" {
		p.Name = "test-tag"
	}
	q := repository.New(pool)
	tag, err := q.CreateTag(context.Background(), repository.CreateTagParams{
		UserID: p.UserID,
		Name:   p.Name,
	})
	if err != nil {
		t.Fatalf("testfactory.CreateTag: %v", err)
	}
	return tag
}
