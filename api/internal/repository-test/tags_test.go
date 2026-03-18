package repository_test

import (
	"testing"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testfactory"
	"task-manager/api/internal/testutils"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCreateTag(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	tag, err := q.CreateTag(t.Context(), repository.CreateTagParams{
		UserID: user.ID,
		Name:   "bug",
	})
	require.NoError(t, err)
	assert.Equal(t, "bug", tag.Name)
	assert.Equal(t, user.ID, tag.UserID)
}

func TestListTags(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "z-last"})
	testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "a-first"})
	testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "m-middle"})

	q := repository.New(pool)
	tags, err := q.ListTags(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, tags, 3)
	// should be ordered by name
	assert.Equal(t, "a-first", tags[0].Name)
	assert.Equal(t, "m-middle", tags[1].Name)
	assert.Equal(t, "z-last", tags[2].Name)
}

func TestListTags_OtherUserIsolation(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})

	testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user1.ID, Name: "tag1"})
	testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user2.ID, Name: "tag2"})

	q := repository.New(pool)
	tags, err := q.ListTags(t.Context(), user1.ID)
	require.NoError(t, err)
	require.Len(t, tags, 1)
	assert.Equal(t, "tag1", tags[0].Name)
}

func TestGetTag(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "feature"})

	q := repository.New(pool)
	got, err := q.GetTag(t.Context(), repository.GetTagParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, "feature", got.Name)
}

func TestGetTag_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	created := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user1.ID})

	q := repository.New(pool)
	_, err := q.GetTag(t.Context(), repository.GetTagParams{ID: created.ID, UserID: user2.ID})
	require.Error(t, err)
}

func TestUpdateTag(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "old-name"})

	newName := "new-name"
	q := repository.New(pool)
	updated, err := q.UpdateTag(t.Context(), repository.UpdateTagParams{
		ID:     created.ID,
		UserID: user.ID,
		Name:   &newName,
	})
	require.NoError(t, err)
	assert.Equal(t, "new-name", updated.Name)
}

func TestDeleteTag(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.DeleteTag(t.Context(), repository.DeleteTagParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetTag(t.Context(), repository.GetTagParams{ID: created.ID, UserID: user.ID})
	require.Error(t, err)
}
