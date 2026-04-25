package handler

import (
	"context"

	"task-manager/api/internal/api"
)

func (h *Handler) HealthOpsPing(_ context.Context) (*api.PingResponse, error) {
	return &api.PingResponse{Message: "pong"}, nil
}
