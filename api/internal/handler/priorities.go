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

func (h *Handler) PriorityOpsList(ctx context.Context) (*api.PriorityList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListPriorities(ctx, userID)
	if err != nil {
		return nil, err
	}

	items := make([]api.Priority, len(rows))
	for i, row := range rows {
		items[i] = *toAPIPriority(row)
	}
	return &api.PriorityList{Items: items}, nil
}

func (h *Handler) PriorityOpsCreate(ctx context.Context, req *api.CreatePriorityRequest) (*api.Priority, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	priorityID, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now()

	row, err := h.q.CreatePriority(ctx, repository.CreatePriorityParams{
		ID:           priorityID,
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
		CreatedAt:    pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt:    pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, err
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "priority.changed", Payload: map[string]any{}})
	return toAPIPriority(row), nil
}

func (h *Handler) PriorityOpsUpdate(ctx context.Context, req *api.UpdatePriorityRequest, params api.PriorityOpsUpdateParams) (*api.Priority, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid priority id")
	}

	row, err := h.q.UpdatePriority(ctx, repository.UpdatePriorityParams{
		ID:           id,
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
		UpdatedAt:    pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	if err != nil {
		return nil, errNotFound("priority not found")
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "priority.changed", Payload: map[string]any{}})
	return toAPIPriority(row), nil
}

func (h *Handler) PriorityOpsDelete(ctx context.Context, params api.PriorityOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid priority id")
	}

	if err := h.q.DeletePriority(ctx, repository.DeletePriorityParams{ID: id, UserID: userID}); err != nil {
		return err
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "priority.changed", Payload: map[string]any{}})
	return nil
}
