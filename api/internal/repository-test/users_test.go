package repository_test

import (
	"testing"
	"time"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testutils"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpsertUser_Insert(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	user, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		ID:          id,
		Email:       "alice@example.com",
		DisplayName: "Alice",
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	require.NoError(t, err)
	assert.Equal(t, "alice@example.com", user.Email)
	assert.Equal(t, "Alice", user.DisplayName)
	assert.NotEmpty(t, user.ID)
}

func TestUpsertUser_Update(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	_, err = q.UpsertUser(t.Context(), repository.UpsertUserParams{
		ID:          id,
		Email:       "alice@example.com",
		DisplayName: "Alice",
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	require.NoError(t, err)

	avatar := "https://example.com/avatar.png"
	updated, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		ID:          id,
		Email:       "alice@example.com",
		DisplayName: "Alice Updated",
		AvatarUrl:   &avatar,
		CreatedAt:   now,
		UpdatedAt:   pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	require.NoError(t, err)
	assert.Equal(t, "Alice Updated", updated.DisplayName)
	assert.Equal(t, &avatar, updated.AvatarUrl)
}

func TestGetUserByID(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	created, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		ID:          id,
		Email:       "bob@example.com",
		DisplayName: "Bob",
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	require.NoError(t, err)

	got, err := q.GetUserByID(t.Context(), created.ID)
	require.NoError(t, err)
	assert.Equal(t, created.ID, got.ID)
	assert.Equal(t, "bob@example.com", got.Email)
}

func TestGetUserByID_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	_, err := q.GetUserByID(t.Context(), nonExistentUUID)
	require.Error(t, err)
}

func TestGetUserByEmail(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	created, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		ID:          id,
		Email:       "carol@example.com",
		DisplayName: "Carol",
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	require.NoError(t, err)

	got, err := q.GetUserByEmail(t.Context(), "carol@example.com")
	require.NoError(t, err)
	assert.Equal(t, created.ID, got.ID)
}

func TestGetUserByEmail_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	_, err := q.GetUserByEmail(t.Context(), "nobody@example.com")
	require.Error(t, err)
}
