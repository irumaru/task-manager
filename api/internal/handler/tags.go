package handler

import (
	"context"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
)

func (h *Handler) TagOpsList(ctx context.Context) (*api.TagList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListTags(ctx, userID)
	if err != nil {
		return nil, err
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

	row, err := h.q.CreateTag(ctx, repository.CreateTagParams{
		UserID: userID,
		Name:   req.Name,
	})
	if err != nil {
		return nil, err
	}
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

	var name *string
	if v, ok := req.Name.Get(); ok {
		name = &v
	}

	row, err := h.q.UpdateTag(ctx, repository.UpdateTagParams{
		ID:     id,
		UserID: userID,
		Name:   name,
	})
	if err != nil {
		return nil, errNotFound("tag not found")
	}
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

	return h.q.DeleteTag(ctx, repository.DeleteTagParams{ID: id, UserID: userID})
}
