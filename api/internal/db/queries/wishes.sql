-- name: ListWishes :many
SELECT
    w.*,
    COALESCE(
        ARRAY_AGG(a.wish_label_id) FILTER (WHERE a.wish_label_id IS NOT NULL),
        '{}'
    )::uuid[] AS label_ids
FROM wishes w
LEFT JOIN wish_label_assignments a ON a.wish_id = w.id
WHERE w.user_id = $1
GROUP BY w.id
ORDER BY w.created_at DESC;

-- name: GetWish :one
SELECT
    w.*,
    COALESCE(
        ARRAY_AGG(a.wish_label_id) FILTER (WHERE a.wish_label_id IS NOT NULL),
        '{}'
    )::uuid[] AS label_ids
FROM wishes w
LEFT JOIN wish_label_assignments a ON a.wish_id = w.id
WHERE w.id = $1 AND w.user_id = $2
GROUP BY w.id;

-- name: CreateWish :one
INSERT INTO wishes (user_id, title, detail) VALUES ($1, $2, $3) RETURNING *;

-- name: UpdateWish :one
-- PUT semantics: full replacement. Client always sends title, detail, archived_at.
-- archived_at: NULL = 通常状態、値あり = アーカイブ済み。
UPDATE wishes SET
    title       = $3,
    detail      = $4,
    archived_at = $5,
    updated_at  = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteWish :exec
DELETE FROM wishes WHERE id = $1 AND user_id = $2;

-- name: ClearWishLabels :exec
DELETE FROM wish_label_assignments WHERE wish_id = $1;

-- name: ReplaceWishLabels :exec
-- PUT 全置換用。unnest で一括 INSERT。空配列でも安全（0 行 INSERT）。
INSERT INTO wish_label_assignments (wish_id, wish_label_id)
SELECT $1, unnest($2::uuid[])
ON CONFLICT DO NOTHING;
