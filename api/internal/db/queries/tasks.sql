-- name: ListTasks :many
SELECT
    t.*,
    COALESCE(
        ARRAY_AGG(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL),
        '{}'
    )::uuid[] AS tag_ids
FROM tasks t
LEFT JOIN task_tags tt ON tt.task_id = t.id
WHERE t.user_id = $1
GROUP BY t.id
ORDER BY t.created_at DESC;

-- name: GetTask :one
SELECT
    t.*,
    COALESCE(
        ARRAY_AGG(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL),
        '{}'
    )::uuid[] AS tag_ids
FROM tasks t
LEFT JOIN task_tags tt ON tt.task_id = t.id
WHERE t.id = $1 AND t.user_id = $2
GROUP BY t.id;

-- name: CreateTask :one
INSERT INTO tasks (user_id, title, memo, due_date, status_id, priority_id)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: UpdateTask :one
UPDATE tasks SET
    title       = COALESCE(sqlc.narg('title'),       title),
    memo        = COALESCE(sqlc.narg('memo'),        memo),
    due_date    = COALESCE(sqlc.narg('due_date'),    due_date),
    status_id   = COALESCE(sqlc.narg('status_id'),   status_id),
    priority_id = COALESCE(sqlc.narg('priority_id'), priority_id),
    updated_at  = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteTask :exec
DELETE FROM tasks WHERE id = $1 AND user_id = $2;

-- name: SetTaskTags :exec
DELETE FROM task_tags WHERE task_id = $1;

-- name: InsertTaskTag :exec
INSERT INTO task_tags (task_id, tag_id) VALUES ($1, $2)
ON CONFLICT DO NOTHING;
