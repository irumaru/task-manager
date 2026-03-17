-- name: ListTags :many
SELECT * FROM tags WHERE user_id = $1 ORDER BY name;

-- name: GetTag :one
SELECT * FROM tags WHERE id = $1 AND user_id = $2;

-- name: CreateTag :one
INSERT INTO tags (user_id, name)
VALUES ($1, $2)
RETURNING *;

-- name: UpdateTag :one
UPDATE tags SET
    name       = COALESCE(sqlc.narg('name'), name),
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteTag :exec
DELETE FROM tags WHERE id = $1 AND user_id = $2;
