-- name: UpsertUser :one
INSERT INTO users (id, email, display_name, avatar_url, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (email) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        avatar_url   = EXCLUDED.avatar_url,
        updated_at   = EXCLUDED.updated_at
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;
