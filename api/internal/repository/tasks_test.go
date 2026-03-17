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

func TestCreateTask(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})

	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{
		UserID:   user.ID,
		Title:    "My Task",
		StatusID: status.ID,
	})

	assert.Equal(t, "My Task", task.Title)
	assert.Equal(t, status.ID, task.StatusID)
	assert.Equal(t, user.ID, task.UserID)
	assert.Nil(t, task.Memo)
	assert.False(t, task.PriorityID.Valid)
}

func TestCreateTask_WithOptionals(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	priority := testfactory.CreatePriority(t, pool, testfactory.PriorityParams{UserID: user.ID})

	memo := "some notes"
	dueDate := pgtype.Timestamptz{Time: time.Now().Add(24 * time.Hour), Valid: true}

	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{
		UserID:     user.ID,
		Title:      "Task with optionals",
		StatusID:   status.ID,
		PriorityID: uuid.NullUUID{UUID: priority.ID, Valid: true},
		Memo:       &memo,
		DueDate:    dueDate,
	})

	assert.Equal(t, &memo, task.Memo)
	assert.True(t, task.PriorityID.Valid)
	assert.Equal(t, priority.ID, task.PriorityID.UUID)
	assert.True(t, task.DueDate.Valid)
}

func TestListTasks(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})

	testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, Title: "Task A", StatusID: status.ID})
	testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, Title: "Task B", StatusID: status.ID})

	q := repository.New(pool)
	rows, err := q.ListTasks(t.Context(), user.ID)
	require.NoError(t, err)
	require.Len(t, rows, 2)
	// ordered by created_at DESC — Task B was inserted later
	assert.Equal(t, "Task B", rows[0].Title)
	assert.Equal(t, "Task A", rows[1].Title)
	// tag_ids should be empty slice (not nil)
	assert.NotNil(t, rows[0].TagIds)
}

func TestListTasks_OtherUserIsolation(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	status1 := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID})
	status2 := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user2.ID})

	testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user1.ID, Title: "User1 Task", StatusID: status1.ID})
	testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user2.ID, Title: "User2 Task", StatusID: status2.ID})

	q := repository.New(pool)
	rows, err := q.ListTasks(t.Context(), user1.ID)
	require.NoError(t, err)
	require.Len(t, rows, 1)
	assert.Equal(t, "User1 Task", rows[0].Title)
}

func TestGetTask(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	tag := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, Title: "Tagged Task", StatusID: status.ID})

	q := repository.New(pool)
	err := q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag.ID})
	require.NoError(t, err)

	got, err := q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Equal(t, "Tagged Task", got.Title)
	require.Len(t, got.TagIds, 1)
	assert.Equal(t, tag.ID, got.TagIds[0])
}

func TestGetTask_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user1.ID, StatusID: status.ID})

	q := repository.New(pool)
	_, err := q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user2.ID})
	require.Error(t, err)
}

func TestUpdateTask(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, Title: "Old Title", StatusID: status.ID})

	newTitle := "New Title"
	q := repository.New(pool)
	updated, err := q.UpdateTask(t.Context(), repository.UpdateTaskParams{
		ID:     task.ID,
		UserID: user.ID,
		Title:  &newTitle,
	})
	require.NoError(t, err)
	assert.Equal(t, "New Title", updated.Title)
	assert.Equal(t, status.ID, updated.StatusID) // unchanged
}

func TestUpdateTask_NotFound(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user1 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user1@example.com"})
	user2 := testfactory.CreateUser(t, pool, testfactory.UserParams{Email: "user2@example.com"})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user1.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user1.ID, StatusID: status.ID})

	newTitle := "Hacked"
	q := repository.New(pool)
	_, err := q.UpdateTask(t.Context(), repository.UpdateTaskParams{
		ID:     task.ID,
		UserID: user2.ID,
		Title:  &newTitle,
	})
	require.Error(t, err)
}

func TestDeleteTask(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, StatusID: status.ID})

	q := repository.New(pool)
	err := q.DeleteTask(t.Context(), repository.DeleteTaskParams{ID: task.ID, UserID: user.ID})
	require.NoError(t, err)

	_, err = q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user.ID})
	require.Error(t, err)
}

func TestInsertTaskTag(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	tag := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, StatusID: status.ID})

	q := repository.New(pool)
	err := q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag.ID})
	require.NoError(t, err)

	got, err := q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user.ID})
	require.NoError(t, err)
	require.Len(t, got.TagIds, 1)
	assert.Equal(t, tag.ID, got.TagIds[0])
}

func TestInsertTaskTag_DuplicateIgnored(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	tag := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, StatusID: status.ID})

	q := repository.New(pool)
	require.NoError(t, q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag.ID}))
	// insert same tag again — ON CONFLICT DO NOTHING
	require.NoError(t, q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag.ID}))

	got, err := q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Len(t, got.TagIds, 1)
}

func TestSetTaskTags(t *testing.T) {
	pool := testutils.SetupTestDB(t)
	user := testfactory.CreateUser(t, pool, testfactory.UserParams{})
	status := testfactory.CreateStatus(t, pool, testfactory.StatusParams{UserID: user.ID})
	tag1 := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "tag1"})
	tag2 := testfactory.CreateTag(t, pool, testfactory.TagParams{UserID: user.ID, Name: "tag2"})
	task := testfactory.CreateTask(t, pool, testfactory.TaskParams{UserID: user.ID, StatusID: status.ID})

	q := repository.New(pool)
	require.NoError(t, q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag1.ID}))
	require.NoError(t, q.InsertTaskTag(t.Context(), repository.InsertTaskTagParams{TaskID: task.ID, TagID: tag2.ID}))

	// SetTaskTags deletes all tags for the task
	err := q.SetTaskTags(t.Context(), task.ID)
	require.NoError(t, err)

	got, err := q.GetTask(t.Context(), repository.GetTaskParams{ID: task.ID, UserID: user.ID})
	require.NoError(t, err)
	assert.Empty(t, got.TagIds)
}
