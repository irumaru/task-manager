package repository_test

import (
	"testing"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testutils"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestUpsertUser_Insert(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	user, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "alice@example.com",
		DisplayName: "Alice",
	})
	require.NoError(t, err)
	assert.Equal(t, "alice@example.com", user.Email)
	assert.Equal(t, "Alice", user.DisplayName)
	assert.NotEmpty(t, user.ID)
}

func TestUpsertUser_Update(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	_, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "alice@example.com",
		DisplayName: "Alice",
	})
	require.NoError(t, err)

	avatar := "https://example.com/avatar.png"
	updated, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "alice@example.com",
		DisplayName: "Alice Updated",
		AvatarUrl:   &avatar,
	})
	require.NoError(t, err)
	assert.Equal(t, "Alice Updated", updated.DisplayName)
	assert.Equal(t, &avatar, updated.AvatarUrl)
}

func TestGetUserByID(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	q := repository.New(pool)

	created, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "bob@example.com",
		DisplayName: "Bob",
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

	created, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "carol@example.com",
		DisplayName: "Carol",
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
