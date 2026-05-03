-- name: ListStatuses :many
SELECT * FROM statuses WHERE user_id = $1 ORDER BY display_order;

-- name: GetStatus :one
SELECT * FROM statuses WHERE id = $1 AND user_id = $2;

-- name: CreateStatus :one
INSERT INTO statuses (id, user_id, name, display_order, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: UpdateStatus :one
UPDATE statuses SET
    name          = $3,
    display_order = $4,
    updated_at    = $5
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteStatus :exec
DELETE FROM statuses WHERE id = $1 AND user_id = $2;
