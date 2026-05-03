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

func TestCreateWish(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	wish, err := q.CreateWish(t.Context(), repository.CreateWishParams{
		ID:        id,
		UserID:    user.ID,
		Title:     "learn Go",
		Detail:    nil,
		CreatedAt: now,
		UpdatedAt: now,
	})
	require.NoError(t, err)
	assert.Equal(t, "learn Go", wish.Title)
	assert.Nil(t, wish.Detail)
}

func TestCreateWish_DetailCanBeNull(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	q := repository.New(pool)

	id, err := uuid.NewV7()
	require.NoError(t, err)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}

	wish, err := q.CreateWish(t.Context(), repository.CreateWishParams{
		ID:        id,
		UserID:    user.ID,
		Title:     "no detail",
		Detail:    nil,
		CreatedAt: now,
		UpdatedAt: now,
	})
	require.NoError(t, err)
	assert.Nil(t, wish.Detail)
}

func TestListWishes(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "wish1"})
	testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "wish2"})

	q := repository.New(pool)
	wishes, err := q.ListWishes(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, wishes, 2)
}

func TestListWishes_OrdersByCreatedAtDesc(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "first"})
	testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "second"})

	q := repository.New(pool)
	wishes, err := q.ListWishes(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, wishes, 2)
	assert.Equal(t, "second", wishes[0].Title)
	assert.Equal(t, "first", wishes[1].Title)
}

func TestListWishes_IncludesLabelIds(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})
	label := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID, Name: "fun"})

	q := repository.New(pool)
	err := q.ReplaceWishLabels(t.Context(), repository.ReplaceWishLabelsParams{
		WishID:  wish.ID,
		Column2: []uuid.UUID{label.ID},
	})
	require.NoError(t, err)

	wishes, err := q.ListWishes(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, wishes, 1)
	require.Len(t, wishes[0].LabelIds, 1)
	assert.Equal(t, label.ID, wishes[0].LabelIds[0])
}

func TestGetWish(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "read books"})

	q := repository.New(pool)
	got, err := q.GetWish(t.Context(), repository.GetWishParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, "read books", got.Title)
}

func TestUpdateWish_ReplacesDetail(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	detail := "old detail"
	created := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Detail: &detail})

	newDetail := "new detail"
	q := repository.New(pool)
	updated, err := q.UpdateWish(t.Context(), repository.UpdateWishParams{
		ID:        created.ID,
		UserID:    user.ID,
		Title:     created.Title,
		Detail:    &newDetail,
		UpdatedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	require.NoError(t, err)
	require.NotNil(t, updated.Detail)
	assert.Equal(t, "new detail", *updated.Detail)
}

func TestUpdateWish_ClearsDetailWhenNullGiven(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	detail := "some detail"
	created := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Detail: &detail})

	q := repository.New(pool)
	updated, err := q.UpdateWish(t.Context(), repository.UpdateWishParams{
		ID:        created.ID,
		UserID:    user.ID,
		Title:     created.Title,
		Detail:    nil,
		UpdatedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	require.NoError(t, err)
	assert.Nil(t, updated.Detail)
}

func TestDeleteWish(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	created := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.DeleteWish(t.Context(), repository.DeleteWishParams{ID: created.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetWish(t.Context(), repository.GetWishParams{ID: created.ID, UserID: user.ID})
	require.Error(t, err)
}

func TestWishLabel_CascadeOnWishDelete(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})
	label := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.ReplaceWishLabels(t.Context(), repository.ReplaceWishLabelsParams{
		WishID:  wish.ID,
		Column2: []uuid.UUID{label.ID},
	})
	require.NoError(t, err)

	err = q.DeleteWish(t.Context(), repository.DeleteWishParams{ID: wish.ID, UserID: user.ID})
	require.NoError(t, err)

	// label itself should still exist
	got, err := q.GetWishLabel(t.Context(), repository.GetWishLabelParams{ID: label.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, label.ID, got.ID)
}

func TestArchiveWish_SetsArchivedAt(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{
		ID:         wish.ID,
		UserID:     user.ID,
		ArchivedAt: now,
	})
	require.NoError(t, err)

	got, err := q.GetWish(t.Context(), repository.GetWishParams{ID: wish.ID, UserID: user.ID})
	require.NoError(t, err)
	require.True(t, got.ArchivedAt.Valid)
}

func TestUnarchiveWish_ClearsArchivedAt(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: wish.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)

	_, err = q.UnarchiveWish(t.Context(), repository.UnarchiveWishParams{ID: wish.ID, UserID: user.ID, UpdatedAt: now})
	require.NoError(t, err)

	got, err := q.GetWish(t.Context(), repository.GetWishParams{ID: wish.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.False(t, got.ArchivedAt.Valid)
}

func TestArchiveWish_IsIdempotent(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: wish.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)

	_, err = q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: wish.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)
}

func TestListWishes_ExcludesArchived(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "visible"})
	archived := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "archived"})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: archived.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)

	wishes, err := q.ListWishes(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, wishes, 1)
	assert.Equal(t, wish.ID, wishes[0].ID)
}

func TestListWishesIncludingArchived_IncludesAll(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "visible"})
	archived := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "archived"})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: archived.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)

	wishes, err := q.ListWishesIncludingArchived(t.Context(), user.ID)
	require.NoError(t, err)
	assert.Len(t, wishes, 2)
}

func TestListWishesIncludingArchived_ArchivedAtBottom(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

	early := pgtype.Timestamptz{Time: time.Now().Add(-2 * time.Second), Valid: true}
	late := pgtype.Timestamptz{Time: time.Now().Add(-1 * time.Second), Valid: true}

	first := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "first", CreatedAt: early, UpdatedAt: early})
	second := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID, Title: "second", CreatedAt: late, UpdatedAt: late})

	q := repository.New(pool)
	now := pgtype.Timestamptz{Time: time.Now(), Valid: true}
	_, err := q.ArchiveWish(t.Context(), repository.ArchiveWishParams{ID: first.ID, UserID: user.ID, ArchivedAt: now})
	require.NoError(t, err)

	wishes, err := q.ListWishesIncludingArchived(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, wishes, 2)
	// 未アーカイブの second が先頭、アーカイブ済みの first が末尾
	assert.Equal(t, second.ID, wishes[0].ID)
	assert.Equal(t, first.ID, wishes[1].ID)
}

func TestWishLabel_CascadeOnWishLabelDelete(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	wish := testfactory.CreateWish(t, pool, testfactory.WishParams{UserID: user.ID})
	label := testfactory.CreateWishLabel(t, pool, testfactory.WishLabelParams{UserID: user.ID})

	q := repository.New(pool)
	err := q.ReplaceWishLabels(t.Context(), repository.ReplaceWishLabelsParams{
		WishID:  wish.ID,
		Column2: []uuid.UUID{label.ID},
	})
	require.NoError(t, err)

	err = q.DeleteWishLabel(t.Context(), repository.DeleteWishLabelParams{ID: label.ID, UserID: user.ID})
	require.NoError(t, err)

	// wish itself should still exist
	got, err := q.GetWish(t.Context(), repository.GetWishParams{ID: wish.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, wish.ID, got.ID)
	// label_ids should be empty
	assert.Empty(t, got.LabelIds)
}
