package handler

import (
	"context"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
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

	row, err := h.q.CreateStatus(ctx, repository.CreateStatusParams{
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
	})
	if err != nil {
		return nil, err
	}
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

	var name *string
	if v, ok := req.Name.Get(); ok {
		name = &v
	}
	var order *int32
	if v, ok := req.DisplayOrder.Get(); ok {
		order = &v
	}

	row, err := h.q.UpdateStatus(ctx, repository.UpdateStatusParams{
		ID:           id,
		UserID:       userID,
		Name:         name,
		DisplayOrder: order,
	})
	if err != nil {
		return nil, errNotFound("status not found")
	}
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

	return h.q.DeleteStatus(ctx, repository.DeleteStatusParams{ID: id, UserID: userID})
}
