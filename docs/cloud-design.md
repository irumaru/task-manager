# クラウド設計ガイド

## 概要

このアプリはオンライン専用として設計されています。ローカルDBは使用せず、すべてのデータは Go API 経由でクラウド（PostgreSQL）に保存されます。

```
┌─────────────────────────────────────┐
│  Flutter App                        │
│  - Google Sign-In                   │
│  - dio（HTTP）                      │
│  - WebSocket（リアルタイム同期）     │
└─────────────┬───────────────────────┘
              │ HTTPS / WSS
              ▼
┌─────────────────────────────────────┐
│  Go API（REST + WebSocket）         │
│  - JWT認証ミドルウェア              │
│  - タスク/優先度/ステータス/タグ CRUD│
│  - WebSocket Hub（イベント配信）    │
└─────────────┬───────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│  PostgreSQL                         │
│  - users / tasks / priorities       │
│  - statuses / tags / task_tags      │
└─────────────────────────────────────┘
```

---

## 1. 認証フロー

```
Flutter                      Go API                    Google
  │                             │                          │
  ├─ google_sign_in.signIn() ──────────────────────────→ │
  │ ←──────── Google ID Token ──────────────────────────── │
  │                             │                          │
  ├─ POST /auth/google ────────→ │                          │
  │   { id_token: "..." }       ├─ Google tokeninfo 検証 → │
  │                             │ ←── { sub, email } ────── │
  │                             ├─ users テーブルに upsert  │
  │ ←── { token: "JWT..." } ─── │                          │
  │                             │                          │
  ├─ JWT を flutter_secure_storage に保存                   │
  ├─ 以降のリクエストに Authorization: Bearer <JWT> を付与  │
```

### JWT ペイロード

```json
{
  "sub": "uuid-of-user",
  "email": "user@example.com",
  "exp": 1234567890
}
```

---

## 2. Go API 設計

### ツールチェーン

```
spec/main.tsp                     ← API 仕様を手書き（設計の唯一の情報源）
    ↓  cd spec && pnpm compile
spec/tsp-output/openapi.yaml      ← 自動生成（手動編集不要）
    ↓  cd api && ogen --target internal/api ../spec/tsp-output/openapi.yaml
api/internal/api/                 ← サーバーコード自動生成（手動編集不要）
    Handler インターフェース・リクエスト/レスポンス型・ルーティング

api/db/queries/*.sql              ← DB クエリを手書き
    ↓  sqlc generate
api/internal/repository/          ← DB アクセスコード自動生成（手動編集不要）
```

### ディレクトリ構成

```
api/
├── cmd/
│   └── server/
│       └── main.go               ← エントリーポイント
├── internal/
│   ├── api/                      ← ogen 自動生成（手動編集不要）
│   │   ├── oas_server_gen.go     ← Handler インターフェース定義
│   │   ├── oas_types_gen.go      ← リクエスト/レスポンス型
│   │   ├── oas_router_gen.go     ← ルーティング（net/http ベース）
│   │   └── oas_security_gen.go  ← SecurityHandler インターフェース
│   ├── auth/
│   │   ├── google.go             ← Google ID Token 検証
│   │   ├── jwt.go                ← JWT 発行・検証
│   │   └── security_handler.go  ← ogen の SecurityHandler 実装（JWT 検証）
│   ├── handler/                  ← ogen の Handler インターフェース実装（手動で記述）
│   │   ├── auth_handler.go       ← POST /auth/google
│   │   ├── task_handler.go       ← タスク CRUD
│   │   ├── priority_handler.go
│   │   ├── status_handler.go
│   │   ├── tag_handler.go
│   │   └── websocket_handler.go  ← WS /ws（OpenAPI 範囲外・手動実装）
│   ├── repository/               ← sqlc 自動生成（手動編集不要）
│   │   ├── db.go
│   │   ├── models.go
│   │   ├── tasks.sql.go
│   │   ├── priorities.sql.go
│   │   ├── statuses.sql.go
│   │   ├── tags.sql.go
│   │   └── users.sql.go
│   └── websocket/
│       ├── hub.go                ← クライアント管理・イベント配信（インターフェース）
│       └── local_hub.go          ← シングルサーバー実装（初期実装）
│       # 将来: redis_hub.go を追加して差し替え可能
├── db/
│   ├── migrations/               ← golang-migrate 管理（up/down ペア）
│   │   ├── 000001_init.up.sql    ← 初期スキーマ（CREATE TABLE）
│   │   └── 000001_init.down.sql  ← ロールバック（DROP TABLE）
│   └── queries/                  ← sqlc に渡す SQL クエリ（手動で記述）
│       ├── tasks.sql
│       ├── priorities.sql
│       ├── statuses.sql
│       ├── tags.sql
│       └── users.sql
├── sqlc.yaml                     ← sqlc 設定ファイル
├── go.mod
├── go.sum
└── Dockerfile
```

### 認証の仕組み（ogen SecurityHandler）

TypeSpec で Bearer 認証を定義すると、ogen が `SecurityHandler` インターフェースを生成します。従来のミドルウェアは不要です。

```go
// ogen が生成するインターフェース（手動編集不要）
type SecurityHandler interface {
    HandleBearerAuth(ctx context.Context, operationName string, t BearerAuth) (context.Context, error)
}

// auth/security_handler.go で実装（手動で記述）
func (h *securityHandler) HandleBearerAuth(ctx context.Context, _ string, t oas.BearerAuth) (context.Context, error) {
    claims, err := h.jwt.Verify(t.Token)
    if err != nil {
        return ctx, oas.ErrUnauthorized
    }
    return context.WithValue(ctx, userIDKey, claims.UserID), nil
}
```

### エンドポイント一覧

| Method | Path | 説明 | 認証 |
|--------|------|------|------|
| POST | /auth/google | Google ID Token → JWT | 不要 |
| DELETE | /auth/logout | ログアウト（クライアント側でJWT削除） | 必要 |
| GET | /tasks | タスク一覧（フィルタ・ソート対応） | 必要 |
| POST | /tasks | タスク作成 | 必要 |
| PUT | /tasks/:id | タスク更新 | 必要 |
| DELETE | /tasks/:id | タスク削除 | 必要 |
| GET | /priorities | 優先度一覧 | 必要 |
| POST | /priorities | 優先度作成 | 必要 |
| PUT | /priorities/:id | 優先度更新 | 必要 |
| DELETE | /priorities/:id | 優先度削除 | 必要 |
| GET | /statuses | ステータス一覧 | 必要 |
| POST | /statuses | ステータス作成 | 必要 |
| PUT | /statuses/:id | ステータス更新 | 必要 |
| DELETE | /statuses/:id | ステータス削除 | 必要 |
| GET | /tags | タグ一覧 | 必要 |
| POST | /tags | タグ作成 | 必要 |
| PUT | /tags/:id | タグ更新 | 必要 |
| DELETE | /tags/:id | タグ削除 | 必要 |
| GET | /ws | WebSocket 接続 | 必要（クエリパラメータ token=） |

### GET /tasks クエリパラメータ

```
GET /tasks?search=foo&priority_ids=id1,id2&status_ids=id1&exclude_status_ids=id2&tag_ids=id1&is_overdue=true&sort_field=due_date&sort_order=asc
```

### WebSocket イベント

サーバーからクライアントへの Push 形式。

```json
{ "type": "task.created",    "data": { ...task } }
{ "type": "task.updated",    "data": { ...task } }
{ "type": "task.deleted",    "data": { "id": "uuid" } }
{ "type": "priority.created","data": { ...priority } }
{ "type": "priority.updated","data": { ...priority } }
{ "type": "priority.deleted","data": { "id": "uuid" } }
{ "type": "status.created",  "data": { ...status } }
{ "type": "status.updated",  "data": { ...status } }
{ "type": "status.deleted",  "data": { "id": "uuid" } }
{ "type": "tag.created",     "data": { ...tag } }
{ "type": "tag.updated",     "data": { ...tag } }
{ "type": "tag.deleted",     "data": { "id": "uuid" } }
```

### スケールアウト方針

**初期実装: シングルサーバー（インプロセス Hub）**

```
Client A ──WS── Server
Client B ──WS──┘  ↑
                  Hub（メモリ内）
```

Hub をインターフェースとして定義し、`LocalHub` として実装します：

```go
// websocket/hub.go（インターフェース）
type Hub interface {
    Register(userID string, conn *websocket.Conn)
    Unregister(userID string, conn *websocket.Conn)
    Broadcast(userID string, event Event)
}

// websocket/local_hub.go（シングルサーバー実装）
type LocalHub struct { clients map[string][]*websocket.Conn }
```

**将来の拡張: Redis Pub/Sub Hub**

スケールアウトが必要になった時点で `RedisHub` を実装し、`main.go` の差し替えだけで対応できます：

```go
// websocket/redis_hub.go（マルチサーバー実装・将来追加）
type RedisHub struct {
    local  *LocalHub
    redis  *redis.Client
}
// Broadcast → Redis publish → 全サーバーの LocalHub に中継
```

---

## 3. PostgreSQL スキーマ

```sql
-- ユーザー
CREATE TABLE users (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub TEXT UNIQUE NOT NULL,
  email      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 優先度（ユーザーごと）
CREATE TABLE priorities (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ステータス（ユーザーごと）
CREATE TABLE statuses (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  sort_order INT  NOT NULL DEFAULT 0,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- タグ（ユーザーごと・名前はユーザー内でユニーク）
CREATE TABLE tags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

-- タスク
CREATE TABLE tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  due_date    TIMESTAMPTZ,
  priority_id UUID REFERENCES priorities(id) ON DELETE SET NULL,
  status_id   UUID REFERENCES statuses(id)   ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- タスク↔タグ（多対多）
CREATE TABLE task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id  UUID NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
  PRIMARY KEY (task_id, tag_id)
);

-- インデックス
CREATE INDEX idx_tasks_user_id    ON tasks(user_id);
CREATE INDEX idx_tasks_status_id  ON tasks(status_id);
CREATE INDEX idx_tasks_due_date   ON tasks(due_date);
CREATE INDEX idx_priorities_user  ON priorities(user_id);
CREATE INDEX idx_statuses_user    ON statuses(user_id);
CREATE INDEX idx_tags_user        ON tags(user_id);
```

### ER 図

```
users
┌──────────────────┐
│ id (PK, UUID)    │
│ google_sub       │
│ email            │
│ created_at       │
└──┬───────────────┘
   │ 1:N (user_id FK)
   ├──────────────────────────────────┐
   │                                  │
   ▼                                  ▼
priorities                         statuses
┌──────────────┐                ┌──────────────┐
│ id (PK)      │                │ id (PK)      │
│ user_id (FK) │                │ user_id (FK) │
│ name         │                │ name         │
│ sort_order   │                │ sort_order   │
│ is_default   │                │ is_default   │
└──────┬───────┘                └──────┬───────┘
       │ FK (priority_id)              │ FK (status_id)
       └──────────────┬────────────────┘
                      ▼
                    tasks
               ┌─────────────────┐
               │ id (PK)         │
               │ user_id (FK)    │
               │ title           │
               │ due_date        │
               │ priority_id(FK) │
               │ status_id (FK)  │
               │ created_at      │
               │ updated_at      │
               └────────┬────────┘
                        │ FK (task_id)
                        ▼
                     task_tags          tags
                ┌──────────────┐   ┌──────────────┐
                │ task_id (FK) │   │ id (PK)      │
                │ tag_id  (FK) │──▶│ user_id (FK) │
                └──────────────┘   │ name         │
                                   └──────────────┘
```

---

## 4. Flutter 側の変更

### パッケージ変更

**削除:**
```yaml
# pubspec.yaml から削除
drift: ...
sqlite3_flutter_libs: ...
drift_dev: ...  # dev_dependencies
```

**追加:**
```yaml
dependencies:
  google_sign_in: ^6.2.0
  flutter_secure_storage: ^9.0.0
  dio: ^5.7.0
  web_socket_channel: ^3.0.0
```

### ディレクトリ変更

**削除するディレクトリ:**
```
app/lib/data/database/      ← drift 関連、全削除
```

**変更するディレクトリ:**
```
app/lib/data/repositories/  ← API 実装に全面差し替え
```

**追加するファイル:**
```
app/lib/
├── data/
│   └── api/
│       ├── api_client.dart          ← dio ラッパー（JWT 自動付与・エラー処理）
│       └── websocket_client.dart    ← WS 接続・再接続管理
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart       ← ログイン状態・JWT 管理（新規）
│   │   └── websocket_provider.dart  ← WS イベント受信・Provider invalidate（新規）
│   └── pages/
│       └── login/
│           └── login_page.dart      ← Google サインインボタン画面（新規）
```

### ドメインモデルの変更

ID の型を `int` から `String`（UUID）に変更します。

```dart
// 変更前
class Task {
  final int id;
  ...
}

// 変更後
class Task {
  final String id;  // UUID
  ...
}
```

同様に `Priority`, `Status`, `Tag` の `id` も `String` に変更。

`TaskFilter` の ID リストも `List<int>` → `List<String>` に変更。

### 新しいプロバイダー依存関係

```
authProvider               ← Google サインイン状態・JWT 管理
    └── apiClientProvider  ← dio（JWT ヘッダ自動付与）
            └── taskRepositoryProvider       → tasksProvider
            └── priorityRepositoryProvider
            └── statusRepositoryProvider
            └── tagRepositoryProvider

websocketProvider          ← WS 接続管理
    → イベント受信時に tasksProvider 等を invalidate
```

### アプリ起動フロー（変更後）

```
main() → ProviderScope → App
                          ├── 未ログイン → LoginPage
                          │                └── Google Sign-In → authProvider に JWT 保存
                          └── ログイン済み → MainShell
                                              ├── TaskListPage
                                              └── SettingsPage
```

---

## 5. リアルタイム同期の仕組み

```
Go API                          Flutter
  │                                │
  │  WS /ws?token=<JWT>  ←──────── │ (ログイン後に接続)
  │                                │
  │  { type: "task.created", ... } │
  │  ──────────────────────────→   │ websocketProvider が受信
  │                                ├─ ref.invalidate(tasksProvider)
  │                                └─ TaskListPage が自動更新
```

複数端末でログインしている場合、一方でタスクを追加すると他方にも即時反映されます。

---

## 6. エラーハンドリング方針

オンライン専用のため、接続エラー時はエラー UI を表示してリトライを促します。

| エラー | UI 対応 |
|--------|---------|
| 未認証（401） | ログイン画面にリダイレクト |
| ネットワークエラー | スナックバーでエラー表示 + リトライボタン |
| サーバーエラー（5xx） | スナックバーでエラー表示 |
| WS 切断 | 自動再接続（指数バックオフ） |

---

## 7. 開発環境

### 構成

```
mise install            ← Go・Node（TypeSpec用）をインストール
docker compose up
    ├── db  （PostgreSQL 16）
    └── api （Go + Air でホットリロード）

flutter run  ← localhost:8080 に接続
```

### ローカル CLI ツール管理（mise）

ローカルで使用する CLI ツールは [mise](https://mise.jdx.dev/) で管理します。リポジトリルートの `.mise.toml` にバージョンを記載するだけで、`mise install` 一発でセットアップが完了します。

Go 製ツールは `go:` プレフィックス、Node.js 製ツールは `npm:` プレフィックスで管理できます。

```toml
# .mise.toml（リポジトリルートに配置）
[tools]
go   = "1.23"
node = "20"
pnpm = "9"

"go:github.com/ogen-go/ogen/cmd/ogen"                 = "latest"
"go:github.com/sqlc-dev/sqlc/cmd/sqlc"                = "latest"
"go:github.com/air-verse/air"                          = "latest"
"go:github.com/golang-migrate/migrate/v4/cmd/migrate"  = "latest"
```

#### セットアップコマンド

```bash
# mise のインストール（未インストールの場合）
curl https://mise.run | sh

# 全ツールを一括インストール
mise install

# TypeSpec コンパイラのインストール（pnpm workspace 経由）
pnpm install
```

### TypeSpec パッケージ管理（pnpm workspace）

TypeSpec 定義は `spec/` パッケージとして管理します。将来 `web/` などを追加する際も同じ workspace に追加するだけで対応できます。

```yaml
# pnpm-workspace.yaml（リポジトリルートに配置）
packages:
  - 'spec'
  # - 'web'   # 将来追加
```

```json
// spec/package.json
{
  "name": "task-manager-spec",
  "private": true,
  "scripts": {
    "compile": "tsp compile ."
  },
  "devDependencies": {
    "@typespec/compiler": "^0.64.0",
    "@typespec/http": "^0.64.0",
    "@typespec/openapi3": "^0.64.0"
  }
}
```

`tsp compile` の出力先は `spec/tsp-output/openapi.yaml` となり、ogen はそこを参照します。

```bash
# TypeSpec → OpenAPI 生成
cd spec && pnpm compile

# OpenAPI → Go コード生成（api/ から実行）
cd api && ogen --target internal/api ../spec/tsp-output/openapi.yaml
```

### ファイル構成

```
task-manager/                ← リポジトリルート
├── .mise.toml               ← ローカル CLI ツールバージョン管理
├── pnpm-workspace.yaml      ← pnpm ワークスペース設定
├── spec/                    ← TypeSpec パッケージ
│   ├── package.json
│   ├── main.tsp             ← API 定義（手動で記述）
│   └── tsp-output/
│       └── openapi.yaml     ← tsp compile で自動生成
├── docker-compose.yml       ← ローカル開発用
├── api/
│   ├── .air.toml            ← Air 設定（ホットリロード）
│   ├── Dockerfile           ← 本番用
│   └── Dockerfile.dev       ← 開発用（Air 込み）
└── app/                     ← Flutter
```

### docker-compose.yml

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: taskmanager
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data

  api:
    build:
      context: ./api
      dockerfile: Dockerfile.dev
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/taskmanager?sslmode=disable
      JWT_SECRET: dev-secret-change-in-production
    volumes:
      - ./api:/app          # ソースコードをマウント（Air がホットリロード）
      - go_cache:/root/go   # Go モジュールキャッシュ
    depends_on:
      - db

volumes:
  pg_data:
  go_cache:
```

### api/Dockerfile.dev

```dockerfile
FROM golang:1.23
RUN go install github.com/air-verse/air@latest
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
CMD ["air", "-c", ".air.toml"]
```

### api/.air.toml（主要設定）

```toml
[build]
cmd = "go build -o ./tmp/server ./cmd/server"
bin = "./tmp/server"
include_ext = ["go"]
exclude_dir = ["internal/api", "internal/repository"]  # 生成コードは監視不要
```

### 起動コマンド

```bash
# 初回セットアップ
docker compose up -d db
sleep 3
docker compose run --rm api migrate -path ./db/migrations -database $DATABASE_URL up

# 通常起動（コード変更で自動再起動）
docker compose up

# Flutter（別ターミナル）
cd app && flutter run
```

### Flutter の API エンドポイント設定

```dart
// core/constants/app_constants.dart
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',  // ローカル開発
);
```

本番では `flutter run --dart-define=API_BASE_URL=https://api.example.com` で切り替え。
