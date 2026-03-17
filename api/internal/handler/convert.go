package handler

import (
	"task-manager/api/internal/api"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

func toAPIUser(u repository.User) *api.UserProfile {
	avatarUrl := api.NilString{Null: true}
	if u.AvatarUrl != nil {
		avatarUrl.SetTo(*u.AvatarUrl)
	}
	return &api.UserProfile{
		ID:          u.ID.String(),
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarUrl:   avatarUrl,
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

func pgtzFromPtr(t *pgtype.Timestamptz) pgtype.Timestamptz {
	if t == nil {
		return pgtype.Timestamptz{}
	}
	return *t
}
