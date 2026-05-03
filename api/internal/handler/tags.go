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

func (h *Handler) TagOpsList(ctx context.Context) (*api.TagList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListTags(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to list tags: %w", err)
	}

	items := make([]api.Tag, len(rows))
	for i, row := range rows {
		items[i] = *toAPITag(row)
	}
	return &api.TagList{Items: items}, nil
}

func (h *Handler) TagOpsCreate(ctx context.Context, req *api.CreateTagRequest) (*api.Tag, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	tagID, err := uuid.NewV7()
	if err != nil {
		return nil, fmt.Errorf("failed to generate tag id: %w", err)
	}

	now := time.Now()

	row, err := h.q.CreateTag(ctx, repository.CreateTagParams{
		ID:        tagID,
		UserID:    userID,
		Name:      req.Name,
		CreatedAt: pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt: pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create tag: %w", err)
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "tag.changed", Payload: map[string]any{}})
	return toAPITag(row), nil
}

func (h *Handler) TagOpsUpdate(ctx context.Context, req *api.UpdateTagRequest, params api.TagOpsUpdateParams) (*api.Tag, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid tag id")
	}

	row, err := h.q.UpdateTag(ctx, repository.UpdateTagParams{
		ID:        id,
		UserID:    userID,
		Name:      req.Name,
		UpdatedAt: pgtype.Timestamptz{Time: time.Now(), Valid: true},
	})
	if err != nil {
		return nil, errNotFound("tag not found")
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "tag.changed", Payload: map[string]any{}})
	return toAPITag(row), nil
}

func (h *Handler) TagOpsDelete(ctx context.Context, params api.TagOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid tag id")
	}

	if err := h.q.DeleteTag(ctx, repository.DeleteTagParams{ID: id, UserID: userID}); err != nil {
		return fmt.Errorf("failed to delete tag: %w", err)
	}
	h.hub.Broadcast(userID, websocket.Event{Type: "tag.changed", Payload: map[string]any{}})
	return nil
}
