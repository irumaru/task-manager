package repository_test

import (
	"testing"
	"time"

	"task-manager/api/internal/repository"
	"task-manager/api/internal/testfactory"
	"task-manager/api/internal/testutils"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCreateWishLabel(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	label, err := q.CreateWishLabel(t.Context(), repository.CreateWishLabelParams{
		ID:        id,
		UserID:    user.ID,
		Name:      "travel",
		CreatedAt: now,
		UpdatedAt: now,
	})
	require.NoError(t, err)
	assert.Equal(t, "travel", label.Name)
	assert.Equal(t, user.ID, label.UserID)
}

func TestListWishLabels(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "z-last"})
	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "a-first"})
	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "m-middle"})

	q := repository.New(pool)
	labels, err := q.ListWishLabels(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, labels, 3)
	assert.Equal(t, "a-first", labels[0].Name)
	assert.Equal(t, "m-middle", labels[1].Name)
	assert.Equal(t, "z-last", labels[2].Name)
}

func TestListWishLabels_OtherUserIsolation(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})

	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user1.ID, Name: "label1"})
	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user2.ID, Name: "label2"})

	q := repository.New(pool)
	labels, err := q.ListWishLabels(t.Context(), user1.ID)
	require.NoError(t, err)
	require.Len(t, labels, 1)
	assert.Equal(t, "label1", labels[0].Name)
}

func TestGetWishLabel(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "sports"})

	q := repository.New(pool)
	got, err := q.GetWishLabel(t.Context(), repository.GetWishLabelParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, "sports", got.Name)
}

func TestUpdateWishLabel(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "old-name"})

	q := repository.New(pool)
	updated, err := q.UpdateWishLabel(t.Context(), repository.UpdateWishLabelParams{
		ID:        created.ID,
		UserID:    user.ID,
		Name:      "new-name",
		UpdatedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	require.NoError(t, err)
	assert.Equal(t, "new-name", updated.Name)
}

func TestDeleteWishLabel(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.DeleteWishLabel(t.Context(), repository.DeleteWishLabelParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetWishLabel(t.Context(), repository.GetWishLabelParams{ID: created.ID, UserID: user.ID})
	require.Error(t, err)
}

func TestCreateWishLabel_DuplicateName(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "music"})

	q := repository.New(pool)
	dupID, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	_, err = q.CreateWishLabel(t.Context(), repository.CreateWishLabelParams{
		ID:        dupID,
		UserID:    user.ID,
		Name:      "music",
		CreatedAt: now,
		UpdatedAt: now,
	})
	require.Error(t, err)
}

func TestCreateWishLabel_SameNameDifferentUser(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user1.ID, Name: "music"})

	q := repository.New(pool)
	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	label, err := q.CreateWishLabel(t.Context(), repository.CreateWishLabelParams{
		ID:        id,
		UserID:    user2.ID,
		Name:      "music",
		CreatedAt: now,
		UpdatedAt: now,
	})
	require.NoError(t, err)
	assert.Equal(t, "music", label.Name)
}
