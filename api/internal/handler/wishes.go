package handler

import (
	"context"
	"errors"
	"strings"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"
	"task-manager/api/internal/websocket"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
)

func (h *Handler) WishOpsList(ctx context.Context) (*api.WishList, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	rows, err := h.q.ListWishes(ctx, userID)
	if err != nil {
		return nil, err
	}

	items := make([]api.Wish, len(rows))
	for i, row := range rows {
		items[i] = toAPIWishFromRow(row)
	}
	return &api.WishList{Items: items}, nil
}

func (h *Handler) WishOpsGet(ctx context.Context, params api.WishOpsGetParams) (*api.Wish, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid wish id")
	}

	row, err := h.q.GetWish(ctx, repository.GetWishParams{ID: id, UserID: userID})
	if err != nil {
		return nil, errNotFound("wish not found")
	}

	result := toAPIWishFromGetRow(row)
	return &result, nil
}

func (h *Handler) WishOpsCreate(ctx context.Context, req *api.CreateWishRequest) (*api.Wish, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errBadRequest("title must not be empty")
	}
	if strings.ContainsAny(req.Title, "\n\r") {
		return nil, errBadRequest("title must not contain newlines")
	}

	labelIDs, err := parseWishLabelIDs(req.LabelIds)
	if err != nil {
		return nil, err
	}

	var detail *string
	if v, ok := req.Detail.Get(); ok {
		detail = &v
	}

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	qtx := h.q.WithTx(tx)

	wish, err := qtx.CreateWish(ctx, repository.CreateWishParams{
		UserID: userID,
		Title:  req.Title,
		Detail: detail,
	})
	if err != nil {
		return nil, err
	}

	if len(labelIDs) > 0 {
		if err := qtx.ReplaceWishLabels(ctx, repository.ReplaceWishLabelsParams{
			WishID:  wish.ID,
			Column2: labelIDs,
		}); err != nil {
			if isFKViolation(err) {
				return nil, errBadRequest("one or more label_ids do not exist")
			}
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	result := toAPIWishFromWish(wish, labelIDs)
	h.hub.Broadcast(userID, websocket.Event{Type: "wish.changed", Payload: map[string]any{}})
	return &result, nil
}

func (h *Handler) WishOpsUpdate(ctx context.Context, req *api.UpdateWishRequest, params api.WishOpsUpdateParams) (*api.Wish, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return nil, errBadRequest("invalid wish id")
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		return nil, errBadRequest("title must not be empty")
	}
	if strings.ContainsAny(req.Title, "\n\r") {
		return nil, errBadRequest("title must not contain newlines")
	}

	labelIDs, err := parseWishLabelIDs(req.LabelIds)
	if err != nil {
		return nil, err
	}

	var detail *string
	if v, ok := req.Detail.Get(); ok {
		detail = &v
	}

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	qtx := h.q.WithTx(tx)

	wish, err := qtx.UpdateWish(ctx, repository.UpdateWishParams{
		ID:     id,
		UserID: userID,
		Title:  req.Title,
		Detail: detail,
	})
	if err != nil {
		return nil, errNotFound("wish not found")
	}

	if err := qtx.ClearWishLabels(ctx, wish.ID); err != nil {
		return nil, err
	}

	if len(labelIDs) > 0 {
		if err := qtx.ReplaceWishLabels(ctx, repository.ReplaceWishLabelsParams{
			WishID:  wish.ID,
			Column2: labelIDs,
		}); err != nil {
			if isFKViolation(err) {
				return nil, errBadRequest("one or more label_ids do not exist")
			}
			return nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	result := toAPIWishFromWish(wish, labelIDs)
	h.hub.Broadcast(userID, websocket.Event{Type: "wish.changed", Payload: map[string]any{}})
	return &result, nil
}

func (h *Handler) WishOpsDelete(ctx context.Context, params api.WishOpsDeleteParams) error {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return errUnauthorized("unauthenticated")
	}

	id, err := uuid.Parse(params.ID)
	if err != nil {
		return errBadRequest("invalid wish id")
	}

	if err := h.q.DeleteWish(ctx, repository.DeleteWishParams{ID: id, UserID: userID}); err != nil {
		return err
	}

	h.hub.Broadcast(userID, websocket.Event{Type: "wish.changed", Payload: map[string]any{}})
	return nil
}

func parseWishLabelIDs(ids []string) ([]uuid.UUID, error) {
	result := make([]uuid.UUID, 0, len(ids))
	for _, s := range ids {
		id, err := uuid.Parse(s)
		if err != nil {
			return nil, errBadRequest("invalid label_id: " + s)
		}
		result = append(result, id)
	}
	return result, nil
}

func isFKViolation(err error) bool {
	var pgErr *pgconn.PgError
	if pgErr, ok := err.(*pgconn.PgError); ok {
		return pgErr.Code == "23503"
	}
	_ = pgErr
	return false
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}
