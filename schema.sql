-- Task Manager database schema
-- This file is the single source of truth. Use atlas to generate migrations.

CREATE SCHEMA IF NOT EXISTS taskmanager;
SET search_path TO taskmanager;

CREATE TABLE users (
    id           UUID        PRIMARY KEY,
    email        TEXT        NOT NULL UNIQUE,
    display_name TEXT        NOT NULL,
    avatar_url   TEXT,
    created_at   TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE statuses (
    id            UUID        PRIMARY KEY,
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name          TEXT        NOT NULL,
    display_order INT         NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL,
    UNIQUE (user_id, name)
);

CREATE TABLE tags (
    id         UUID        PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    UNIQUE (user_id, name)
);

CREATE TABLE tasks (
    id          UUID        PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    memo        TEXT,
    due_date    TIMESTAMPTZ,
    status_id   UUID        NOT NULL REFERENCES statuses(id),
    importance  INT         NOT NULL DEFAULT 1 CHECK (importance BETWEEN 1 AND 3),
    urgency     INT         NOT NULL DEFAULT 1 CHECK (urgency BETWEEN 1 AND 3),
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE task_tags (
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id  UUID NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

CREATE TABLE wishes (
    id          UUID        PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    detail      TEXT,
    archived_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE wish_labels (
    id         UUID        PRIMARY KEY,
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    UNIQUE (user_id, name)
);

CREATE TABLE wish_label_assignments (
    wish_id       UUID NOT NULL REFERENCES wishes(id)      ON DELETE CASCADE,
    wish_label_id UUID NOT NULL REFERENCES wish_labels(id) ON DELETE CASCADE,
    PRIMARY KEY (wish_id, wish_label_id)
);
