package handler

import (
	"context"
	"time"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"
	"task-manager/api/internal/websocket"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

func (h *Handler) TaskOpsList(ctx context.Context) (*api.TaskList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListTasks(ctx, userID)
	if err != nil {
		return nil, err
	}

	items := make([]api.Task, len(rows))
	for i, row := range rows {
		items[i] = toAPITaskFromRow(row)
	}
	return &api.TaskList{Items: items}, nil
}

func (h *Handler) TaskOpsCreate(ctx context.Context, req *api.CreateTaskRequest) (*api.Task, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	statusID, err := uuid.Parse(req.StatusId)
	if err != nil {
		return nil, errBadRequest("invalid status_id")
	}

	var priorityID uuid.NullUUID
	if v, ok := req.PriorityId.Get(); ok {
		id, err := uuid.Parse(v)
		if err != nil {
			return nil, errBadRequest("invalid priority_id")
		}
		priorityID = uuid.NullUUID{UUID: id, Valid: true}
	}

	var dueDate pgtype.Timestamptz
	if v, ok := req.DueDate.Get(); ok {
		dueDate = pgtype.Timestamptz{Time: v, Valid: true}
	}

	var memo *string
	if v, ok := req.Memo.Get(); ok {
		memo = &v
	}

	taskID, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now()

	task, err := h.q.CreateTask(ctx, repository.CreateTaskParams{
		ID:         taskID,
		UserID:     userID,
		Title:      req.Title,
		Memo:       memo,
		DueDate:    dueDate,
		StatusID:   statusID,
		PriorityID: priorityID,
		CreatedAt:  pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt:  pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, err
	}

	// Insert tag associations
	for _, tagIDStr := range req.TagIds {
		tagID, err := uuid.Parse(tagIDStr)
		if err != nil {
			return nil, errBadRequest("invalid tag_id: " + tagIDStr)
		}
		if err := h.q.InsertTaskTag(ctx, repository.InsertTaskTagParams{
			TaskID: taskID,
			TagID:  tagID,
		}); err != nil {
			return nil, err
		}
	}

	result := toAPITaskFromTask(task)
	result.TagIds = req.TagIds
	h.hub.Broadcast(userID, websocket.Event{Type: "task.changed", Payload: map[string]any{}})
	return &result, nil
}

func (h *Handler) TaskOpsGet(ctx context.Context, params api.TaskOpsGetParams) (*api.Task, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid task id")
	}

	row, err := h.q.GetTask(ctx, repository.GetTaskParams{ID: id, UserID: userID})
	if err != nil {
		return nil, errNotFound("task not found")
	}

	result := toAPITaskFromGetRow(row)
	return &result, nil
}

func (h *Handler) TaskOpsUpdate(ctx context.Context, req *api.UpdateTaskRequest, params api.TaskOpsUpdateParams) (*api.Task, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid task id")
	}

	var memo *string
	if !req.Memo.Null {
		memo = &req.Memo.Value
	}

	var dueDate pgtype.Timestamptz
	if !req.DueDate.Null {
		dueDate = pgtype.Timestamptz{Time: req.DueDate.Value, Valid: true}
	}

	statusID, err := uuid.Parse(req.StatusId)
	if err != nil {
		return nil, errBadRequest("invalid status_id")
	}

	var priorityID uuid.NullUUID
	if !req.PriorityId.Null {
		pid, err := uuid.Parse(req.PriorityId.Value)
		if err != nil {
			return nil, errBadRequest("invalid priority_id")
		}
		priorityID = uuid.NullUUID{UUID: pid, Valid: true}
	}

	task, err := h.q.UpdateTask(ctx, repository.UpdateTaskParams{
		ID:         id,
		UserID:     userID,
		Title:      req.Title,
		Memo:       memo,
		DueDate:    dueDate,
		StatusID:   statusID,
		PriorityID: priorityID,
		UpdatedAt:  pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	if err != nil {
		return nil, errNotFound("task not found")
	}

	// PUT semantics: always replace all tag associations
	if err := h.q.SetTaskTags(ctx, task.ID); err != nil {
		return nil, err
	}
	for _, tagIDStr := range req.TagIds {
		tagID, err := uuid.Parse(tagIDStr)
		if err != nil {
			return nil, errBadRequest("invalid tag_id: " + tagIDStr)
		}
		if err := h.q.InsertTaskTag(ctx, repository.InsertTaskTagParams{
			TaskID: task.ID,
			TagID:  tagID,
		}); err != nil {
			return nil, err
		}
	}

	result := toAPITaskFromTask(task)
	result.TagIds = req.TagIds
	h.hub.Broadcast(userID, websocket.Event{Type: "task.changed", Payload: map[string]any{}})
	return &result, nil
}

func (h *Handler) TaskOpsDelete(ctx context.Context, params api.TaskOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid task id")
	}

	if err := h.q.DeleteTask(ctx, repository.DeleteTaskParams{ID: id, UserID: userID}); err != nil {
		return err
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "task.changed", Payload: map[string]any{}})
	return nil
}
