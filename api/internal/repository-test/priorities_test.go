package repository_test

import (
	"testing"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testfactory"
	"task-manager/api/internal/testutils"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCreatePriority(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	priority, err := q.CreatePriority(t.Context(), repository.CreatePriorityParams{
		UserID:       user.ID,
		Name:         "High",
		DisplayOrder: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, "High", priority.Name)
	assert.Equal(t, int32(1), priority.DisplayOrder)
	assert.Equal(t, user.ID, priority.UserID)
}

func TestListPriorities(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "Low", DisplayOrder: 3})
	testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "High", DisplayOrder: 1})
	testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "Medium", DisplayOrder: 2})

	q := repository.New(pool)
	priorities, err := q.ListPriorities(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, priorities, 3)
	// should be ordered by display_order
	assert.Equal(t, "High", priorities[0].Name)
	assert.Equal(t, "Medium", priorities[1].Name)
	assert.Equal(t, "Low", priorities[2].Name)
}

func TestListPriorities_OtherUserIsolation(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})

	testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user1.ID, Name: "P1"})
	testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user2.ID, Name: "P2"})

	q := repository.New(pool)
	priorities, err := q.ListPriorities(t.Context(), user1.ID)
	require.NoError(t, err)
	require.Len(t, priorities, 1)
	assert.Equal(t, "P1", priorities[0].Name)
}

func TestGetPriority(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "Urgent"})

	q := repository.New(pool)
	got, err := q.GetPriority(t.Context(), repository.GetPriorityParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, "Urgent", got.Name)
}

func TestGetPriority_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user1.ID})

	q := repository.New(pool)
	_, err := q.GetPriority(t.Context(), repository.GetPriorityParams{ID: created.ID, UserID: user2.ID})
	require.Error(t, err)
}

func TestUpdatePriority(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "Normal", DisplayOrder: 2})

	newName := "Critical"
	newOrder := int32(1)
	q := repository.New(pool)
	updated, err := q.UpdatePriority(t.Context(), repository.UpdatePriorityParams{
		ID:           created.ID,
		UserID:       user.ID,
		Name:         &newName,
		DisplayOrder: &newOrder,
	})
	require.NoError(t, err)
	assert.Equal(t, "Critical", updated.Name)
	assert.Equal(t, int32(1), updated.DisplayOrder)
}

func TestUpdatePriority_PartialUpdate(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID, Name: "Original", DisplayOrder: 5})

	newName := "Renamed"
	q := repository.New(pool)
	updated, err := q.UpdatePriority(t.Context(), repository.UpdatePriorityParams{
		ID:     created.ID,
		UserID: user.ID,
		Name:   &newName,
	})
	require.NoError(t, err)
	assert.Equal(t, "Renamed", updated.Name)
	assert.Equal(t, int32(5), updated.DisplayOrder) // unchanged
}

func TestDeletePriority(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.DeletePriority(t.Context(), repository.DeletePriorityParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetPriority(t.Context(), repository.GetPriorityParams{ID: created.ID, UserID: user.ID})
	require.Error(t, err)
}

func TestDeletePriority_OtherUserCannotDelete(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	created := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user1.ID})

	q := repository.New(pool)
	err := q.DeletePriority(t.Context(), repository.DeletePriorityParams{ID: created.ID, UserID: user2.ID})
	require.NoError(t, err)

	_, err = q.GetPriority(t.Context(), repository.GetPriorityParams{ID: created.ID, UserID: user1.ID})
	require.NoError(t, err)
}
