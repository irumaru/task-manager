-- name: ListPriorities :many
SELECT * FROM priorities WHERE user_id = $1 ORDER BY display_order;

-- name: GetPriority :one
SELECT * FROM priorities WHERE id = $1 AND user_id = $2;

-- name: CreatePriority :one
INSERT INTO priorities (user_id, name, display_order)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdatePriority :one
UPDATE priorities SET
    name          = COALESCE(sqlc.narg('name'),          name),
    display_order = COALESCE(sqlc.narg('display_order'), display_order),
    updated_at    = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeletePriority :exec
DELETE FROM priorities WHERE id = $1 AND user_id = $2;
