# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Task manager app with a Go REST API (`api/`), Flutter client (`app/`), and Atlas-based DB migrator (`migrator/`). API spec is defined in TypeSpec (`spec/`). The project is written primarily in Japanese (README, comments, docs).

## Common Commands

All tooling is managed via [mise](https://mise.jdx.dev/). Run `mise install` to set up Go, sqlc, atlas, node, pnpm, and ogen.

### Local Development

```bash
docker compose up -d          # Start PostgreSQL + API (with Air hot-reload)
mise run db:migrate            # Apply schema.sql to DB
```

### Code Generation

```bash
mise run gen                   # Run all code generation (TypeSpec → OpenAPI → ogen, sqlc)
mise run gen:tsp               # TypeSpec only (spec/ → spec/tsp-output/openapi.yaml)
mise run gen:go:ogen           # ogen only (OpenAPI → api/internal/api/oas_*_gen.go)
mise run gen:go:sqlc           # sqlc only (SQL queries → api/internal/repository/*.sql.go)
mise run clean                 # Delete all generated code
```

After changing `schema.sql` or `spec/main.tsp`, run `mise run gen` and commit generated files. CI (`test-generated.yml`) verifies generated files are in sync on every PR.

### Database Migrations

```bash
mise run db:migrations:create  # Generate Atlas migration diff from schema.sql
```

### Tests

```bash
# Repository integration tests (require local PostgreSQL with taskmanager_template DB)
cd api && go test ./internal/repository-test/...

# Single test
cd api && go test ./internal/repository-test/ -run TestFunctionName

# E2E tests (require running API server + DB)
cd api && go test ./e2e/...
```

Repository tests use `testutils.SetupTestDB()` which creates a temporary DB from `taskmanager_template` and drops it after each test.

E2E tests use [runn](https://github.com/k1LoW/runn) with YAML scenarios in `api/e2e/scenarios/`.

## Architecture

### Code Generation Pipeline

```
spec/main.tsp (hand-written TypeSpec)
  → tsp compile → spec/tsp-output/openapi.yaml
  → ogen        → api/internal/api/oas_*_gen.go (server interface, types, router)

schema.sql (hand-written PostgreSQL schema)
  → sqlc generate → api/internal/repository/*.sql.go

schema.sql
  → atlas migrate diff → migrator/migrations/*.sql
```

**Do not edit files in `api/internal/api/` or `api/internal/repository/*.sql.go`** — they are generated. Edit `spec/main.tsp`, `api/internal/db/queries/*.sql`, or `schema.sql` instead.

### API Server (`api/`)

- **Entry point**: `cmd/server/main.go` — wires up DB pool, JWT service, WebSocket hub, ogen server
- **`internal/handler/`** — Implements the ogen-generated `api.Handler` interface. One file per domain (tasks, statuses, priorities, tags, auth). Uses `statusError` for HTTP error mapping.
- **`internal/auth/`** — JWT (HS256) issuance/validation, Google OAuth token exchange, ogen SecurityHandler
- **`internal/repository/`** — sqlc-generated DB access via pgx/v5. Queries defined in `internal/db/queries/`
- **`internal/websocket/`** — Hub interface with `LocalHub` implementation for real-time event push
- **`internal/bootstrap/`** — pgxpool setup with schema search_path configuration

### Flutter Client (`app/`)

Uses Riverpod 3.x for state management with `riverpod_generator`. Follows a layered architecture: `data/` (API clients, repositories) → `domain/` (models, interfaces) → `presentation/` (screens, providers, widgets).

### Multi-tenant Data Model

All domain tables (tasks, statuses, priorities, tags) are scoped to a `user_id` with `ON DELETE CASCADE`. The DB uses a `taskmanager` schema (not public).

## Environment Variables

Required: `JWT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`. See `.env.example`.
