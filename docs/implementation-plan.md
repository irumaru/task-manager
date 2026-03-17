# 実装計画

## フェーズ構成

```
Phase 1: Go API 基盤（認証・DB）
Phase 2: Go API エンドポイント実装
Phase 3: Flutter クライアント移行
Phase 4: WebSocket リアルタイム同期
Phase 5: 動作確認・調整
```

---

## Phase 1: Go API 基盤

### 1-1. プロジェクト初期化

- `api/` ディレクトリを作成し `go mod init` を実行
- `docker-compose.yml`（PostgreSQL + API）と `api/Dockerfile.dev`（Air 込み）を作成
- `api/.air.toml` を作成（生成コードディレクトリを監視対象から除外）
- ローカル CLI ツールのセットアップ（mise）
  - リポジトリルートに `.mise.toml` を作成
    - `go`・`node`・`pnpm` を記載
    - `go:` プレフィックスで ogen・sqlc・air・atlas を記載
  - `mise install` を実行（全ツールを一括インストール）
- TypeSpec パッケージのセットアップ（pnpm workspace）
  - リポジトリルートに `pnpm-workspace.yaml` を作成（`spec` を記載）
  - `spec/package.json` を作成（`@typespec/compiler` 等の依存を記載）
  - `pnpm install` を実行（TypeSpec コンパイラをインストール）
- Go 依存パッケージ導入
  - `github.com/ogen-go/ogen`（生成コードのランタイム・net/http サーバー内蔵）
  - `github.com/jackc/pgx/v5`（PostgreSQL ドライバー）
  - `golang-jwt/jwt/v5`（JWT 発行・検証）
  - `gorilla/websocket`（WebSocket、/ws エンドポイント用）
  - ※ gin は不要（ogen の net/http ベースルーターを使用）

### 1-2. PostgreSQL スキーマ・sqlc セットアップ

- `api/db/schema.sql` に理想スキーマを記述（single source of truth）
  - テーブル定義（users / priorities / statuses / tags / tasks / task_tags）+ インデックス
- atlas で初回マイグレーションファイルを生成
  ```bash
  # schema.sql の内容から初回マイグレーションファイルを生成
  atlas migrate diff init \
    --to "file://db/schema.sql" \
    --dev-url "docker://postgres/16/dev?search_path=public"
  # → db/migrations/20240101000000_init.sql と atlas.sum が生成される
  ```
- マイグレーション実行コマンド
  ```bash
  # 未適用のマイグレーションを適用
  atlas migrate apply --url "$DATABASE_URL" --dir "file://db/migrations"
  # ロールバック（1つ戻す）
  atlas migrate down --url "$DATABASE_URL" --dir "file://db/migrations" --amount 1
  ```
- スキーマ変更時のワークフロー
  ```bash
  # 1. schema.sql を直接編集（理想状態を更新）
  # 2. 差分からマイグレーションファイルを生成
  atlas migrate diff add_description_to_tasks \
    --to "file://db/schema.sql" \
    --dev-url "docker://postgres/16/dev?search_path=public"
  # 3. 生成されたファイルをコミット
  # 4. atlas migrate apply で適用
  ```
- `api/db/queries/` に各テーブルの SQL クエリファイルを作成
  - `tasks.sql`, `priorities.sql`, `statuses.sql`, `tags.sql`, `users.sql`
- `api/sqlc.yaml` に sqlc 設定を記述（`schema: "db/schema.sql"` で理想スキーマを参照）
- `sqlc generate` で `internal/repository/` 配下に Go コードを自動生成
  - 生成されたファイルは手動編集不要（`db.go`, `models.go`, `*.sql.go`）

### 1-3. TypeSpec API 定義・ogen コード生成

- リポジトリルートの `spec/main.tsp` に TypeSpec で API 仕様を記述する
  ```typespec
  import "@typespec/http";
  using TypeSpec.Http;

  @service({ title: "Task Manager API" })
  namespace TaskManagerAPI;

  // JWT Bearer 認証の定義
  model BearerAuth is HttpAuth.BearerAuthScheme;

  @route("/tasks")
  interface Tasks {
    @get list(...ListTasksParams): Task[] | UnauthorizedResponse;
    @post create(@body body: CreateTaskRequest): Task | UnauthorizedResponse;
    @put("{id}") update(@path id: string, @body body: UpdateTaskRequest): Task | ...;
    @delete("{id}") delete(@path id: string): void | ...;
  }
  // ...
  ```
- `cd spec && pnpm compile` で `spec/tsp-output/openapi.yaml` を生成
- `cd api && ogen --target internal/api ../spec/tsp-output/openapi.yaml` で Go コードを生成
  - 生成されたファイル（`oas_*_gen.go`）は手動編集不要
  - `Handler` インターフェース・リクエスト/レスポンス型・ルーターが生成される
  - `SecurityHandler` インターフェースが生成される（JWT 検証に使用）

### 1-4. Google 認証実装

- `internal/auth/google.go`: Google tokeninfo API で ID Token を検証
- `internal/auth/jwt.go`: JWT 発行（有効期限 24h）・検証
- `internal/auth/security_handler.go`: ogen の `SecurityHandler` を実装（ミドルウェア不要）
  - `HandleBearerAuth()` で JWT を検証し `context` にユーザーID を格納

### 1-5. 認証エンドポイント実装

- `internal/handler/auth_handler.go`: ogen の `Handler` インターフェースを実装
  - `POST /auth/google`: ID Token 受取 → ユーザー upsert → JWT 返却

---

## Phase 2: Go API エンドポイント実装

### 2-1. sqlc クエリ定義・コード生成

- `api/db/queries/` に CRUD クエリを SQL で記述する
  ```sql
  -- tasks.sql の例
  -- name: GetTasksByUser :many
  SELECT t.*, ... FROM tasks t WHERE t.user_id = $1 ...;

  -- name: CreateTask :one
  INSERT INTO tasks (...) VALUES (...) RETURNING *;
  ```
- `sqlc generate` を実行して `internal/repository/` に Go コードを生成
- 生成されたコード（`models.go`, `tasks.sql.go` 等）は手動編集しない

### 2-2. タスク CRUD（Handler 実装）

- `internal/handler/task_handler.go` に ogen の `Handler` インターフェースを実装
  - `ListTasks`: フィルタ・ソートのクエリパラメータを受け取り sqlc で検索
  - `CreateTask`: タスク作成（タグの紐付けを含む）
  - `UpdateTask`: タスク更新（タグの差分更新）
  - `DeleteTask`: タスク削除
- 各操作後に WebSocket Hub を通じてイベントを配信

### 2-3. 優先度・ステータス・タグ CRUD

- 各リソースに GET / POST / PUT / DELETE を実装
- 初回ログイン時にデフォルトの優先度・ステータスを自動作成

### 2-4. デフォルトデータ自動生成

- `POST /auth/google` のユーザー作成時に以下を INSERT
  - 優先度: 「高」「低」（sort_order: 1, 2）
  - ステータス: 「未着手」「進行中」「完了」（sort_order: 1, 2, 3）

---

## Phase 3: Flutter クライアント移行

### 3-1. ドメインモデル変更

- `Task`, `Priority`, `Status`, `Tag` の `id: int` → `id: String`（UUID）
- `TaskFilter` の `List<int>` → `List<String>`
- `SortField`, `SortOrder` 列挙型はそのまま流用

### 3-2. パッケージ変更

- `pubspec.yaml` から `drift` / `sqlite3_flutter_libs` / `drift_dev` を削除
- `google_sign_in` / `flutter_secure_storage` / `dio` / `web_socket_channel` を追加

### 3-3. データ層の実装

- `data/database/` ディレクトリを削除
- `data/api/api_client.dart`: dio ラッパー（JWT 自動付与・エラー処理・タイムアウト設定）
- `data/repositories/` を API 呼び出しベースに全面書き換え

### 3-4. 認証プロバイダー・ログイン画面

- `presentation/providers/auth_provider.dart`: Google Sign-In フロー・JWT 保存・ログアウト
- `presentation/pages/login/login_page.dart`: Google サインインボタン画面

### 3-5. API プロバイダー

- `presentation/providers/api_provider.dart`
  - `database_provider.dart` を削除し置き換え
  - `apiClientProvider`（dio）
  - `taskRepositoryProvider`, `priorityRepositoryProvider` 等を提供

### 3-6. 既存プロバイダーの調整

- `task_provider.dart`, `filter_provider.dart` 等: ID の型を `String` に変更するだけで、ロジックはほぼ流用可能

### 3-7. app.dart の認証ガード

- `authProvider` の状態を watch し、未ログイン → `LoginPage`、ログイン済み → `MainShell` に切り替え

---

## Phase 4: WebSocket リアルタイム同期

### 4-1. Go 側 WebSocket Hub 実装

- `internal/websocket/hub.go`:
  - クライアント登録・登録解除
  - ユーザーIDごとのルーティング（他ユーザーのイベントは送らない）
  - イベント配信（Broadcast）
- `handler/websocket_handler.go`: `GET /ws?token=<JWT>` で接続・JWT 検証
- 各 CRUD ハンドラーで操作後に Hub.Broadcast を呼ぶ

### 4-2. Flutter 側 WebSocket クライアント

- `data/api/websocket_client.dart`:
  - JWT 付き WS 接続
  - 自動再接続（指数バックオフ：1s → 2s → 4s → 最大 30s）
  - イベント受信・Stream で提供
- `presentation/providers/websocket_provider.dart`:
  - ログイン後に接続
  - イベント種別に応じて対象 Provider を `invalidate`

---

## Phase 5: 動作確認・調整

### 5-1. エンドポイントのテスト

- curl / Postman で全エンドポイントを確認
- JWT 検証・ユーザー分離を確認

### 5-2. Flutter 動作確認

- Android / iOS / Windows / macOS それぞれで起動確認
- ログイン → タスク操作 → ログアウトのフローを確認

### 5-3. リアルタイム同期確認

- 2端末でログインし、一方の変更が他方に即時反映されることを確認

### 5-4. エラーケース確認

- ネットワーク切断時の UI 表示
- JWT 期限切れ時の再ログイン誘導
- WS 切断後の自動再接続

---

## 実装順序の理由

```
Go API → Flutter クライアント移行 → WebSocket
```

- API が先に完成していると、Flutter 側を実装しながら実際に動作確認できる
- WebSocket はシンプルな REST が動いてから追加することで、デバッグが容易になる
