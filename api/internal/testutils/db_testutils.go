package testutils

import (
	"context"
	"fmt"
	"math/rand"
	"testing"

	"task-manager/api/internal/bootstrap"

	"github.com/jackc/pgx/v5/pgxpool"
)

func SetupTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	// テスト用DBを生成
	dbName := "taskmanager_test_" + randomAlphabet(8)
	err := createTestDB(context.Background(), dbName)
	if err != nil {
		t.Fatal(err)
	}

	// 作成したテスト用DBに接続
	dsn := "postgres://postgres:example@127.0.0.1:5432/" + dbName + "?search_path=taskmanager&sslmode=disable"
	db, err := bootstrap.SetupDatabase(t.Context(), dsn)
	if err != nil {
		t.Fatal(err)
	}

	// テスト終了後にDBを削除
	t.Cleanup(func() {
		db.Close()
		err := deleteDB(context.Background(), dbName)
		if err != nil {
			t.Fatal(err)
		}
	})

	return db
}

func createTestDB(ctx context.Context, dbName string) error {
	// データベース接続
	dsn := "postgres://postgres:example@127.0.0.1:5432/?sslmode=disable"
	db, err := bootstrap.SetupDatabase(ctx, dsn)
	if err != nil {
		return fmt.Errorf("failed to connect db: %w", err)
	}
	defer db.Close()

	// テスト用DBの作成
	_, err = db.Exec(ctx, `CREATE DATABASE `+dbName+` WITH TEMPLATE taskmanager_template;`)
	if err != nil {
		return fmt.Errorf("failed to create test db: %w", err)
	}

	return nil
}

func deleteDB(ctx context.Context, dbName string) error {
	// データベース接続
	dsn := "postgres://postgres:example@127.0.0.1:5432/?sslmode=disable"
	db, err := bootstrap.SetupDatabase(ctx, dsn)
	if err != nil {
		return fmt.Errorf("failed to connect db: %w", err)
	}
	defer db.Close()

	// データベース削除
	_, err = db.Exec(ctx, `DROP DATABASE IF EXISTS `+dbName+`;`)
	if err != nil {
		return fmt.Errorf("failed to delete test db: %w", err)
	}

	return nil
}

func randomAlphabet(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyz"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}
