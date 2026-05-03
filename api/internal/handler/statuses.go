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

func (h *Handler) StatusOpsList(ctx context.Context) (*api.StatusList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListStatuses(ctx, userID)
	if err != nil {
		return nil, err
	}

	items := make([]api.Status, len(rows))
	for i, row := range rows {
		items[i] = *toAPIStatus(row)
	}
	return &api.StatusList{Items: items}, nil
}

func (h *Handler) StatusOpsCreate(ctx context.Context, req *api.CreateStatusRequest) (*api.Status, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	statusID, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now()

	row, err := h.q.CreateStatus(ctx, repository.CreateStatusParams{
		ID:           statusID,
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
		CreatedAt:    pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt:    pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, err
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "status.changed", Payload: map[string]any{}})
	return toAPIStatus(row), nil
}

func (h *Handler) StatusOpsUpdate(ctx context.Context, req *api.UpdateStatusRequest, params api.StatusOpsUpdateParams) (*api.Status, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid status id")
	}

	row, err := h.q.UpdateStatus(ctx, repository.UpdateStatusParams{
		ID:           id,
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
		UpdatedAt:    pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	if err != nil {
		return nil, errNotFound("status not found")
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "status.changed", Payload: map[string]any{}})
	return toAPIStatus(row), nil
}

func (h *Handler) StatusOpsDelete(ctx context.Context, params api.StatusOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid status id")
	}

	if err := h.q.DeleteStatus(ctx, repository.DeleteStatusParams{ID: id, UserID: userID}); err != nil {
		return err
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "status.changed", Payload: map[string]any{}})
	return nil
}
