package handler

import (
	"task-manager/api/internal/api"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

func toAPIUser(u repository.User) *api.UserProfile {
	avatarURL := api.NilString{Null: true}
	if u.AvatarUrl != nil {
		avatarURL.SetTo(*u.AvatarUrl)
	}
	return &api.UserProfile{
		ID:          u.ID.String(),
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarUrl:   avatarURL,
	}
}

func toAPIStatus(s repository.Status) *api.Status {
	return &api.Status{
		ID:           s.ID.String(),
		Name:         s.Name,
		DisplayOrder: s.DisplayOrder,
	}
}

func toAPIPriority(p repository.Priority) *api.Priority {
	return &api.Priority{
		ID:           p.ID.String(),
		Name:         p.Name,
		DisplayOrder: p.DisplayOrder,
	}
}

func toAPITag(t repository.Tag) *api.Tag {
	return &api.Tag{
		ID:   t.ID.String(),
		Name: t.Name,
	}
}

func toAPITaskFromRow(row repository.ListTasksRow) api.Task {
	return api.Task{
		ID:         row.ID.String(),
		Title:      row.Title,
		Memo:       nilStringFromPtr(row.Memo),
		DueDate:    nilDateTimeFromPgtz(row.DueDate),
		StatusId:   row.StatusID.String(),
		PriorityId: nilStringFromNullUUID(row.PriorityID),
		TagIds:     uuidSliceToStrings(row.TagIds),
		CreatedAt:  row.CreatedAt.Time,
		UpdatedAt:  row.UpdatedAt.Time,
	}
}

func toAPITaskFromGetRow(row repository.GetTaskRow) api.Task {
	return api.Task{
		ID:         row.ID.String(),
		Title:      row.Title,
		Memo:       nilStringFromPtr(row.Memo),
		DueDate:    nilDateTimeFromPgtz(row.DueDate),
		StatusId:   row.StatusID.String(),
		PriorityId: nilStringFromNullUUID(row.PriorityID),
		TagIds:     uuidSliceToStrings(row.TagIds),
		CreatedAt:  row.CreatedAt.Time,
		UpdatedAt:  row.UpdatedAt.Time,
	}
}

func toAPITaskFromTask(t repository.Task) api.Task {
	return api.Task{
		ID:         t.ID.String(),
		Title:      t.Title,
		Memo:       nilStringFromPtr(t.Memo),
		DueDate:    nilDateTimeFromPgtz(t.DueDate),
		StatusId:   t.StatusID.String(),
		PriorityId: nilStringFromNullUUID(t.PriorityID),
		TagIds:     []string{},
		CreatedAt:  t.CreatedAt.Time,
		UpdatedAt:  t.UpdatedAt.Time,
	}
}

func nilStringFromPtr(s *string) api.NilString {
	if s == nil {
		return api.NilString{Null: true}
	}
	return api.NewNilString(*s)
}

func nilStringFromNullUUID(u uuid.NullUUID) api.NilString {
	if !u.Valid {
		return api.NilString{Null: true}
	}
	return api.NewNilString(u.UUID.String())
}

func nilDateTimeFromPgtz(t pgtype.Timestamptz) api.NilDateTime {
	if !t.Valid {
		return api.NilDateTime{Null: true}
	}
	return api.NewNilDateTime(t.Time)
}

func uuidSliceToStrings(ids []uuid.UUID) []string {
	out := make([]string, len(ids))
	for i, id := range ids {
		out[i] = id.String()
	}
	return out
}

func toAPIWishLabel(l repository.WishLabel) *api.WishLabel {
	return &api.WishLabel{ID: l.ID.String(), Name: l.Name}
}

func toAPIWish(id uuid.UUID, userID uuid.UUID, title string, detail *string, archivedAt, createdAt, updatedAt pgtype.Timestamptz, labelIDs []uuid.UUID) api.Wish {
	return api.Wish{
		ID:         id.String(),
		Title:      title,
		Detail:     nilStringFromPtr(detail),
		ArchivedAt: nilDateTimeFromPgtz(archivedAt),
		LabelIds:   uuidSliceToStrings(labelIDs),
		CreatedAt:  createdAt.Time,
		UpdatedAt:  updatedAt.Time,
	}
}

func toAPIWishFromRow(row repository.ListWishesRow) api.Wish {
	return toAPIWish(row.ID, row.UserID, row.Title, row.Detail, row.ArchivedAt, row.CreatedAt, row.UpdatedAt, row.LabelIds)
}

func toAPIWishFromIncludingArchivedRow(row repository.ListWishesIncludingArchivedRow) api.Wish {
	return toAPIWish(row.ID, row.UserID, row.Title, row.Detail, row.ArchivedAt, row.CreatedAt, row.UpdatedAt, row.LabelIds)
}

func toAPIWishFromGetRow(row repository.GetWishRow) api.Wish {
	return toAPIWish(row.ID, row.UserID, row.Title, row.Detail, row.ArchivedAt, row.CreatedAt, row.UpdatedAt, row.LabelIds)
}

func toAPIWishFromWish(w repository.Wish, labelIDs []uuid.UUID) api.Wish {
	return toAPIWish(w.ID, w.UserID, w.Title, w.Detail, w.ArchivedAt, w.CreatedAt, w.UpdatedAt, labelIDs)
}
