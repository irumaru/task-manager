package handler

import (
	"context"
	"log/slog"

	"task-manager/api/internal/api"
	"task-manager/api/internal/auth"
	"task-manager/api/internal/repository"
)

func (h *Handler) AuthOpsGoogleLogin(ctx context.Context, req *api.GoogleAuthRequest) (*api.AuthResponse, error) {
	info, err := auth.VerifyGoogleIDToken(ctx, req.IdToken)
	if err != nil {
		slog.WarnContext(ctx, "failed to verify Google ID token", "err", err)
		return nil, errUnauthorized("invalid Google ID token")
	}

	user, err := h.q.UpsertUser(ctx, repository.UpsertUserParams{
		Email:       info.Email,
		DisplayName: info.Name,
		AvatarUrl:   nilPtr(info.Picture),
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

	user, err := h.q.UpsertUser(ctx, repository.UpsertUserParams{
		Email:       info.Email,
		DisplayName: info.Name,
		AvatarUrl:   nilPtr(info.Picture),
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
		return nil, errUnauthorized("unauthenticated")
	}

	user, err := h.q.GetUserByID(ctx, userID)
	if err != nil {
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
