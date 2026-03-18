package repository_test

import (
	"testing"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testfactory"
	"task-manager/api/internal/testutils"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCreateStatus(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	status, err := q.CreateStatus(t.Context(), repository.CreateStatusParams{
		UserID:       user.ID,
		Name:         "In Progress",
		DisplayOrder: 1,
	})
	require.NoError(t, err)
	assert.Equal(t, "In Progress", status.Name)
	assert.Equal(t, int32(1), status.DisplayOrder)
	assert.Equal(t, user.ID, status.UserID)
}

func TestListStatuses(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID, Name: "Todo", DisplayOrder: 1})
	testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID, Name: "Done", DisplayOrder: 2})

	q := repository.New(pool)
	statuses, err := q.ListStatuses(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, statuses, 2)
	assert.Equal(t, "Todo", statuses[0].Name)
	assert.Equal(t, "Done", statuses[1].Name)
}

func TestListStatuses_OtherUserIsolation(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})

	testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID, Name: "User1 Status"})
	testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user2.ID, Name: "User2 Status"})

	q := repository.New(pool)
	statuses, err := q.ListStatuses(t.Context(), user1.ID)
	require.NoError(t, err)
	require.Len(t, statuses, 1)
	assert.Equal(t, "User1 Status", statuses[0].Name)
}

func TestGetStatus(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID, Name: "Review"})

	q := repository.New(pool)
	got, err := q.GetStatus(t.Context(), repository.GetStatusParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, created.ID, got.ID)
	assert.Equal(t, "Review", got.Name)
}

func TestGetStatus_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID})

	// user2 cannot get user1's status
	q := repository.New(pool)
	_, err := q.GetStatus(t.Context(), repository.GetStatusParams{ID: created.ID, UserID: user2.ID})
	require.Error(t, err)
}

func TestUpdateStatus(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID, Name: "Old Name", DisplayOrder: 1})

	newName := "New Name"
	newOrder := int32(5)
	q := repository.New(pool)
	updated, err := q.UpdateStatus(t.Context(), repository.UpdateStatusParams{
		ID:           created.ID,
		UserID:       user.ID,
		Name:         &newName,
		DisplayOrder: &newOrder,
	})
	require.NoError(t, err)
	assert.Equal(t, "New Name", updated.Name)
	assert.Equal(t, int32(5), updated.DisplayOrder)
}

func TestUpdateStatus_PartialUpdate(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID, Name: "Original", DisplayOrder: 3})

	// update only name, leave display_order unchanged (COALESCE)
	newName := "Renamed"
	q := repository.New(pool)
	updated, err := q.UpdateStatus(t.Context(), repository.UpdateStatusParams{
		ID:     created.ID,
		UserID: user.ID,
		Name:   &newName,
	})
	require.NoError(t, err)
	assert.Equal(t, "Renamed", updated.Name)
	assert.Equal(t, int32(3), updated.DisplayOrder)
}

func TestDeleteStatus(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.DeleteStatus(t.Context(), repository.DeleteStatusParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetStatus(t.Context(), repository.GetStatusParams{ID: created.ID, UserID: user.ID})
	require.Error(t, err)
}

func TestDeleteStatus_OtherUserCannotDelete(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	created := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID})

	q := repository.New(pool)
	// delete with wrong user — no error returned but row is untouched
	err := q.DeleteStatus(t.Context(), repository.DeleteStatusParams{ID: created.ID, UserID: user2.ID})
	require.NoError(t, err)

	// record should still exist for user1
	_, err = q.GetStatus(t.Context(), repository.GetStatusParams{ID: created.ID, UserID: user1.ID})
	require.NoError(t, err)
}
