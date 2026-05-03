package handler

import (
	"context"
	"log/slog"
	"time"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

func (h *Handler) AuthOpsGoogleLogin(ctx context.Context, req *api.GoogleAuthRequest) (*api.AuthResponse, error) {
	info, err := auth.VerifyGoogleIDToken(ctx, req.IdToken)
	if err != nil {
		slog.WarnContext(ctx, "failed to verify Google ID token", "err", err)
		return nil, errUnauthorized("invalid Google ID token")
	}

	userID, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now()

	user, err := h.q.UpsertUser(ctx, repository.UpsertUserParams{
		ID:          userID,
		Email:       info.Email,
		DisplayName: info.Name,
		AvatarUrl:   nilPtr(info.Picture),
		CreatedAt:   pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt:   pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, err
	}

	token, err := h.jwt.Issue(user.ID, user.Email)
	if err != nil {
		return nil, err
	}

	return &api.AuthResponse{
		AccessToken: token,
		User:        *toAPIUser(user),
	}, nil
}

func (h *Handler) AuthOpsGoogleLoginWithCode(ctx context.Context, req *api.GoogleAuthCodeRequest) (*api.AuthResponse, error) {
	info, err := auth.ExchangeGoogleCode(ctx, req.Code, req.RedirectUri, h.googleClientID, h.googleClientSecret)
	if err != nil {
		slog.WarnContext(ctx, "failed to exchange Google auth code", "err", err)
		return nil, errUnauthorized("invalid authorization code")
	}

	userID, err := uuid.NewV7()
	if err != nil {
		return nil, err
	}

	now := time.Now()

	user, err := h.q.UpsertUser(ctx, repository.UpsertUserParams{
		ID:          userID,
		Email:       info.Email,
		DisplayName: info.Name,
		AvatarUrl:   nilPtr(info.Picture),
		CreatedAt:   pgtype.Timestamptz{Time: now, Valid: true},
		UpdatedAt:   pgtype.Timestamptz{Time: now, Valid: true},
	})
	if err != nil {
		return nil, err
	}

	token, err := h.jwt.Issue(user.ID, user.Email)
	if err != nil {
		return nil, err
	}

	return &api.AuthResponse{
		AccessToken: token,
		User:        *toAPIUser(user),
	}, nil
}

func (h *Handler) AuthOpsGetMe(ctx context.Context) (*api.UserProfile, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		slog.WarnContext(ctx, "failed to get user ID from context", "err", err)
		return nil, errUnauthorized("unauthenticated")
	}

	user, err := h.q.GetUserByID(ctx, userID)
	if err != nil {
		slog.DebugContext(ctx, "failed to get user by ID", "err", err)
		return nil, errNotFound("user not found")
	}

	return toAPIUser(user), nil
}

func nilPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
