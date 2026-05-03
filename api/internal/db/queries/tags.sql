-- name: ListTags :many
SELECT * FROM tags WHERE user_id = $1 ORDER BY name;

-- name: GetTag :one
SELECT * FROM tags WHERE id = $1 AND user_id = $2;

-- name: CreateTag :one
INSERT INTO tags (id, user_id, name, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateTag :one
UPDATE tags SET
    name       = $3,
    updated_at = $4
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteTag :exec
DELETE FROM tags WHERE id = $1 AND user_id = $2;
