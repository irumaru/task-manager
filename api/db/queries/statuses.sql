-- name: ListStatuses :many
SELECT * FROM statuses WHERE user_id = $1 ORDER BY display_order;

-- name: GetStatus :one
SELECT * FROM statuses WHERE id = $1 AND user_id = $2;

-- name: CreateStatus :one
INSERT INTO statuses (user_id, name, display_order)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateStatus :one
UPDATE statuses SET
    name          = COALESCE(sqlc.narg('name'),          name),
    display_order = COALESCE(sqlc.narg('display_order'), display_order),
    updated_at    = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteStatus :exec
DELETE FROM statuses WHERE id = $1 AND user_id = $2;
