package handler

import (
	"context"
	"fmt"
	"time"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"
	"task-manager/api/internal/websocket"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

func (h *Handler) WishLabelOpsList(ctx context.Context) (*api.WishLabelList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListWishLabels(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to list wish labels: %w", err)
	}

	items := make([]api.WishLabel, len(rows))
	for i, row := range rows {
		items[i] = *toAPIWishLabel(row)
	}
	return &api.WishLabelList{Items: items}, nil
}

func (h *Handler) WishLabelOpsCreate(ctx context.Context, req *api.CreateWishLabelRequest) (*api.WishLabel, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	labelID, err := uuid.NewV7()
	if err != nil {
		return nil, fmt.Errorf("failed to generate wish label id: %w", err)
	}

	now := time.Now()

	row, err := h.q.CreateWishLabel(ctx, repository.CreateWishLabelParams{
		ID:        labelID,
		UserID:    userID,
		Name:      req.Name,
		CreatedAt: pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt: pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		if isUniqueViolation(err) {
			return nil, errConflict("wish_label name already exists")
		}
		return nil, fmt.Errorf("failed to create wish label: %w", err)
	}

	result := toAPIWishLabel(row)
	h.hub.Broadcast(userID, websocket.Event{Type: "wish_label.changed", Payload: map[string]any{}})
	return result, nil
}

func (h *Handler) WishLabelOpsUpdate(ctx context.Context, req *api.UpdateWishLabelRequest, params api.WishLabelOpsUpdateParams) (*api.WishLabel, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid wish_label id")
	}

	row, err := h.q.UpdateWishLabel(ctx, repository.UpdateWishLabelParams{
		ID:        id,
		UserID:    userID,
		Name:      req.Name,
		UpdatedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	if err != nil {
		if isUniqueViolation(err) {
			return nil, errConflict("wish_label name already exists")
		}
		return nil, errNotFound("wish_label not found")
	}

	result := toAPIWishLabel(row)
	h.hub.Broadcast(userID, websocket.Event{Type: "wish_label.changed", Payload: map[string]any{}})
	return result, nil
}

func (h *Handler) WishLabelOpsDelete(ctx context.Context, params api.WishLabelOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid wish_label id")
	}

	if err := h.q.DeleteWishLabel(ctx, repository.DeleteWishLabelParams{ID: id, UserID: userID}); err != nil {
		return fmt.Errorf("failed to delete wish label: %w", err)
	}

	h.hub.Broadcast(userID, websocket.Event{Type: "wish_label.changed", Payload: map[string]any{}})
	return nil
}
