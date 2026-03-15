package handler

import (
	"context"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
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

	row, err := h.q.CreatePriority(ctx, repository.CreatePriorityParams{
		UserID:       userID,
		Name:         req.Name,
		DisplayOrder: req.DisplayOrder,
	})
	if err != nil {
		return nil, err
	}
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

	var name *string
	if v, ok := req.Name.Get(); ok {
		name = &v
	}
	var order *int32
	if v, ok := req.DisplayOrder.Get(); ok {
		order = &v
	}

	row, err := h.q.UpdatePriority(ctx, repository.UpdatePriorityParams{
		ID:           id,
		UserID:       userID,
		Name:         name,
		DisplayOrder: order,
	})
	if err != nil {
		return nil, errNotFound("priority not found")
	}
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

	return h.q.DeletePriority(ctx, repository.DeletePriorityParams{ID: id, UserID: userID})
}
