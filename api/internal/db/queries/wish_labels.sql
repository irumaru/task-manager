-- name: ListWishLabels :many
SELECT * FROM wish_labels WHERE user_id = $1 ORDER BY name;

-- name: GetWishLabel :one
SELECT * FROM wish_labels WHERE id = $1 AND user_id = $2;

-- name: CreateWishLabel :one
INSERT INTO wish_labels (user_id, name) VALUES ($1, $2) RETURNING *;

-- name: UpdateWishLabel :one
-- PUT semantics: full replacement.
UPDATE wish_labels SET
    name       = $3,
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteWishLabel :exec
DELETE FROM wish_labels WHERE id = $1 AND user_id = $2;
