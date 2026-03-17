package e2e_test

import (
	"context"
	"os"
	"testing"

	"task-manager/api/internal/auth"
	"task-manager/api/internal/bootstrap"
	"task-manager/api/internal/repository"

	"github.com/k1LoW/runn"
)

func TestE2E(t *testing.T) {
	// docker-compose のデフォルト値にフォールバック
	dbURL := envOr("DATABASE_URL", "postgres://postgres:example@127.0.0.1:5432/taskmanager?search_path=taskmanager&sslmode=disable")
	jwtSecret := envOr("JWT_SECRET", "change-me-in-production")
	apiURL := envOr("API_URL", "http://localhost:8080")

	pool, err := bootstrap.SetupDatabase(t.Context(), dbURL)
	if err != nil {
		t.Fatalf("bootstrap.SetupDatabase: %v", err)
	}
	t.Cleanup(pool.Close)

	// テスト用ユーザーを作成 (UpsertUser なので冪等)
	q := repository.New(pool)
	user, err := q.UpsertUser(t.Context(), repository.UpsertUserParams{
		Email:       "e2e-test@example.com",
		DisplayName: "E2E Test User",
	})
	if err != nil {
		t.Fatalf("UpsertUser: %v", err)
	}
	// テスト終了後にユーザーと関連データを削除 (ON DELETE CASCADE)
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM users WHERE id = $1", user.ID)
	})

	token, err := auth.NewJWTService(jwtSecret).Issue(user.ID, user.Email)
	if err != nil {
		t.Fatalf("jwt.Issue: %v", err)
	}

	o, err := runn.Load("scenarios/*.yaml",
		runn.T(t),
		runn.Runner("req", apiURL),
		runn.Var("token", token),
	)
	if err != nil {
		t.Fatalf("runn.Load: %v", err)
	}
	if err := o.RunN(t.Context()); err != nil {
		t.Fatal(err)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
