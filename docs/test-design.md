# APIテスト設計

## 概要

このドキュメントでは、APIのテスト戦略として以下の2種類のテストを定義する。

- **DBクエリテスト**: `repository` パッケージのSQLクエリをDBに接続して実行する統合テスト
- **E2Eテスト**: `runn` を用いてAPIサーバーに対してHTTPリクエストを送るシナリオテスト
- **WebSocketテスト**: handlerへのbroadcast実装後に追加予定

---

## DBクエリテスト

### 方針

- sqlcで生成されたSQLクエリは静的解析が効かないため、すべてのクエリ関数をテストする
- 実際のPostgreSQLに接続し、クエリの正常動作を確認する
- テスト用DBは `testutils.SetupTestDB` を使用して取得する（テスト終了後に自動削除）
- テストデータの作成は `testfactory` パッケージに切り出して再利用する

### ディレクトリ構成

```
api/internal/
├── testutils/
│   └── db_testutils.go       # 既存: SetupTestDB
├── testfactory/
│   ├── user.go               # ユーザーのテストデータ作成
│   ├── status.go             # ステータスのテストデータ作成
│   ├── priority.go           # 優先度のテストデータ作成
│   ├── tag.go                # タグのテストデータ作成
│   └── task.go               # タスクのテストデータ作成
└── repository/
    ├── users_test.go
    ├── tasks_test.go
    ├── statuses_test.go
    ├── priorities_test.go
    └── tags_test.go
```

### testfactory の設計

各ファクトリは `*pgxpool.Pool` を受け取り、テストデータをDBに挿入して返す。
デフォルト値を持ちつつ、必要に応じて上書きできる `Params` 構造体パターンを採用する。

```go
// testfactory/user.go
package testfactory

import (
    "context"
    "testing"
    "task-manager/api/internal/repository"
    "github.com/jackc/pgx/v5/pgxpool"
)

type UserParams struct {
    Email       string
    DisplayName string
    AvatarUrl   *string
}

func CreateUser(t *testing.T, pool *pgxpool.Pool, p UserParams) repository.User {
    t.Helper()
    if p.Email == "" {
        p.Email = "test@example.com"
    }
    if p.DisplayName == "" {
        p.DisplayName = "Test User"
    }
    q := repository.New(pool)
    user, err := q.UpsertUser(context.Background(), repository.UpsertUserParams{
        Email:       p.Email,
        DisplayName: p.DisplayName,
        AvatarUrl:   p.AvatarUrl,
    })
    if err != nil {
        t.Fatal(err)
    }
    return user
}
```

```go
// testfactory/status.go
package testfactory

type StatusParams struct {
    UserID       uuid.UUID
    Name         string
    DisplayOrder int32
}

func CreateStatus(t *testing.T, pool *pgxpool.Pool, p StatusParams) repository.Status { ... }
```

```go
// testfactory/task.go
package testfactory

type TaskParams struct {
    UserID     uuid.UUID
    Title      string
    StatusID   uuid.UUID  // 必須: 事前に CreateStatus で作成する
    PriorityID uuid.NullUUID
    Memo       *string
    DueDate    pgtype.Timestamptz
}

func CreateTask(t *testing.T, pool *pgxpool.Pool, p TaskParams) repository.Task { ... }
```

### テストケース一覧

#### `repository/users_test.go`

| テスト関数 | 対象クエリ | 確認内容 |
|---|---|---|
| `TestUpsertUser_Insert` | `UpsertUser` | 新規ユーザーが作成される |
| `TestUpsertUser_Update` | `UpsertUser` | 同じemailで再実行すると display_name / avatar_url が更新される |
| `TestGetUserByID` | `GetUserByID` | IDで取得できる |
| `TestGetUserByID_NotFound` | `GetUserByID` | 存在しないIDは `pgx.ErrNoRows` を返す |
| `TestGetUserByEmail` | `GetUserByEmail` | emailで取得できる |
| `TestGetUserByEmail_NotFound` | `GetUserByEmail` | 存在しないemailは `pgx.ErrNoRows` を返す |

#### `repository/statuses_test.go`

| テスト関数 | 対象クエリ | 確認内容 |
|---|---|---|
| `TestCreateStatus` | `CreateStatus` | ステータスが作成される |
| `TestListStatuses` | `ListStatuses` | ユーザーのステータス一覧が `display_order` 順で返る |
| `TestListStatuses_OtherUserIsolation` | `ListStatuses` | 他ユーザーのステータスは含まれない |
| `TestGetStatus` | `GetStatus` | IDとユーザーIDで取得できる |
| `TestGetStatus_NotFound` | `GetStatus` | 他ユーザーのステータスは取得できない |
| `TestUpdateStatus` | `UpdateStatus` | 部分更新が正しく動作する（COALESCE） |
| `TestDeleteStatus` | `DeleteStatus` | 削除される / 他ユーザーは削除できない |

#### `repository/priorities_test.go`

| テスト関数 | 対象クエリ | 確認内容 |
|---|---|---|
| `TestCreatePriority` | `CreatePriority` | 優先度が作成される |
| `TestListPriorities` | `ListPriorities` | `display_order` 順で返る / 他ユーザー分離 |
| `TestGetPriority` | `GetPriority` | 取得できる / 他ユーザーは取得できない |
| `TestUpdatePriority` | `UpdatePriority` | 部分更新が正しく動作する |
| `TestDeletePriority` | `DeletePriority` | 削除される / 他ユーザーは削除できない |

#### `repository/tags_test.go`

| テスト関数 | 対象クエリ | 確認内容 |
|---|---|---|
| `TestCreateTag` | `CreateTag` | タグが作成される |
| `TestListTags` | `ListTags` | `name` 順で返る / 他ユーザー分離 |
| `TestGetTag` | `GetTag` | 取得できる / 他ユーザーは取得できない |
| `TestUpdateTag` | `UpdateTag` | 部分更新が正しく動作する |
| `TestDeleteTag` | `DeleteTag` | 削除される |

#### `repository/tasks_test.go`

| テスト関数 | 対象クエリ | 確認内容 |
|---|---|---|
| `TestCreateTask` | `CreateTask` | タスクが作成される |
| `TestCreateTask_WithOptionals` | `CreateTask` | memo / due_date / priority_id を指定して作成 |
| `TestListTasks` | `ListTasks` | `created_at DESC` 順で返る / tag_ids が集約される |
| `TestListTasks_OtherUserIsolation` | `ListTasks` | 他ユーザーのタスクは含まれない |
| `TestGetTask` | `GetTask` | タグを含むタスクが取得できる |
| `TestGetTask_NotFound` | `GetTask` | 他ユーザーのタスクは取得できない |
| `TestUpdateTask` | `UpdateTask` | 部分更新が正しく動作する（COALESCE） |
| `TestUpdateTask_NotFound` | `UpdateTask` | 他ユーザーのタスクは更新できない |
| `TestDeleteTask` | `DeleteTask` | 削除される |
| `TestInsertTaskTag` | `InsertTaskTag` | タスクにタグが紐づく / 重複挿入は無視される |
| `TestSetTaskTags` | `SetTaskTags` | タスクの全タグ関連が削除される |

### テスト実装例

```go
// repository/statuses_test.go
func TestListStatuses(t *testing.T) {
    pool := testutils.SetupTestDB(t)
    user := testfactory.CreateUser(t, pool, testfactory.UserParams{})

    testfactory.CreateStatus(t, pool, testfactory.StatusParams{
        UserID: user.ID, Name: "Todo", DisplayOrder: 1,
    })
    testfactory.CreateStatus(t, pool, testfactory.StatusParams{
        UserID: user.ID, Name: "Done", DisplayOrder: 2,
    })

    q := repository.New(pool)
    statuses, err := q.ListStatuses(context.Background(), user.ID)
    require.NoError(t, err)
    assert.Len(t, statuses, 2)
    assert.Equal(t, "Todo", statuses[0].Name)
    assert.Equal(t, "Done", statuses[1].Name)
}
```

---

## E2Eテスト

### 方針

- `runn` を使用してHTTPシナリオテストをYAMLファイルで記述する
- すべてのAPIエンドポイントを最低1回テストする
- 認証が必要なエンドポイントはシナリオ実行前にJWTをコード内で生成してrunnの変数に渡す
- テストシナリオは依存関係を考慮してステップ間で変数を受け渡す（`bind` を活用）

### ディレクトリ構成

```
api/
└── e2e/
    ├── e2e_test.go           # runnのGoランナー（JWTの生成・変数注入もここで行う）
    └── scenarios/
        ├── auth.yaml         # GET /auth/me
        ├── tasks.yaml        # CRUD /tasks
        ├── statuses.yaml     # CRUD /statuses
        ├── priorities.yaml   # CRUD /priorities
        └── tags.yaml         # CRUD /tags
```

### 対象エンドポイント一覧

| エンドポイント | メソッド | ハンドラ | テストシナリオファイル |
|---|---|---|---|
| `/auth/google` | POST | `AuthOpsGoogleLogin` | ※対象外（Google IDトークン検証が必要） |
| `/auth/me` | GET | `AuthOpsGetMe` | `auth.yaml` |
| `/tasks` | GET | `TaskOpsList` | `tasks.yaml` |
| `/tasks` | POST | `TaskOpsCreate` | `tasks.yaml` |
| `/tasks/{id}` | GET | `TaskOpsGet` | `tasks.yaml` |
| `/tasks/{id}` | PATCH | `TaskOpsUpdate` | `tasks.yaml` |
| `/tasks/{id}` | DELETE | `TaskOpsDelete` | `tasks.yaml` |
| `/statuses` | GET | `StatusOpsList` | `statuses.yaml` |
| `/statuses` | POST | `StatusOpsCreate` | `statuses.yaml` |
| `/statuses/{id}` | PATCH | `StatusOpsUpdate` | `statuses.yaml` |
| `/statuses/{id}` | DELETE | `StatusOpsDelete` | `statuses.yaml` |
| `/priorities` | GET | `PriorityOpsList` | `priorities.yaml` |
| `/priorities` | POST | `PriorityOpsCreate` | `priorities.yaml` |
| `/priorities/{id}` | PATCH | `PriorityOpsUpdate` | `priorities.yaml` |
| `/priorities/{id}` | DELETE | `PriorityOpsDelete` | `priorities.yaml` |
| `/tags` | GET | `TagOpsList` | `tags.yaml` |
| `/tags` | POST | `TagOpsCreate` | `tags.yaml` |
| `/tags/{id}` | PATCH | `TagOpsUpdate` | `tags.yaml` |
| `/tags/{id}` | DELETE | `TagOpsDelete` | `tags.yaml` |

### テスト用JWT

`POST /auth/google` はGoogle IDトークンの検証が必要なため、E2Eテストではこのエンドポイントを経由せずJWTを発行する。

`e2e_test.go` の `TestMain` で以下を行う：
1. `testutils.SetupTestDB` でテスト用DBを用意する
2. `testfactory.CreateUser` でテスト用ユーザーをDBに挿入する
3. `auth.Issue(userID, email)` を直接呼び出してJWTを生成する
4. 生成したJWTをrunnの `vars` として全シナリオに注入する

```go
// e2e/e2e_test.go
package e2e_test

import (
    "testing"
    "task-manager/api/internal/auth"
    "task-manager/api/internal/testfactory"
    "task-manager/api/internal/testutils"
    "github.com/k1LoW/runn"
)

func TestE2E(t *testing.T) {
    // テスト用DBとユーザーを準備
    pool := testutils.SetupTestDB(t)
    user := testfactory.CreateUser(t, pool, testfactory.UserParams{
        Email:       "e2e@example.com",
        DisplayName: "E2E User",
    })

    // JWTをコード内で生成
    jwtManager := auth.NewJWTManager("test-secret")
    token, err := jwtManager.Issue(user.ID, user.Email)
    if err != nil {
        t.Fatal(err)
    }

    // runnシナリオを実行（JWTを変数として注入）
    o, err := runn.Load("scenarios/*.yaml",
        runn.T(t),
        runn.Var("token", token),
    )
    if err != nil {
        t.Fatal(err)
    }
    if err := o.RunN(t.Context()); err != nil {
        t.Fatal(err)
    }
}
```

### シナリオ例: `scenarios/statuses.yaml`

```yaml
desc: ステータスCRUD
runners:
  req: http://localhost:8080
steps:
  create_status:
    desc: ステータス作成
    req:
      /statuses:
        post:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              name: "進行中"
              display_order: 1
    test: |
      current.res.status == 200
      current.res.body.name == "進行中"
    bind:
      status_id: current.res.body.id

  list_statuses:
    desc: ステータス一覧取得
    req:
      /statuses:
        get:
          headers:
            Authorization: "Bearer {{ vars.token }}"
    test: |
      current.res.status == 200
      len(current.res.body.items) >= 1

  update_status:
    desc: ステータス更新
    req:
      /statuses/{{ vars.status_id }}:
        patch:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              name: "完了"
    test: |
      current.res.status == 200
      current.res.body.name == "完了"

  delete_status:
    desc: ステータス削除
    req:
      /statuses/{{ vars.status_id }}:
        delete:
          headers:
            Authorization: "Bearer {{ vars.token }}"
    test: |
      current.res.status == 204
```

### シナリオ例: `scenarios/tasks.yaml`

```yaml
desc: タスクCRUD
runners:
  req: http://localhost:8080
steps:
  # 事前準備: statusとtagを作成
  create_status:
    req:
      /statuses:
        post:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              name: "Todo"
              display_order: 1
    test: current.res.status == 200
    bind:
      status_id: current.res.body.id

  create_tag:
    req:
      /tags:
        post:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              name: "urgent"
    test: current.res.status == 200
    bind:
      tag_id: current.res.body.id

  create_task:
    desc: タスク作成（タグ付き）
    req:
      /tasks:
        post:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              title: "テストタスク"
              status_id: "{{ vars.status_id }}"
              tag_ids:
                - "{{ vars.tag_id }}"
    test: |
      current.res.status == 200
      current.res.body.title == "テストタスク"
      len(current.res.body.tag_ids) == 1
    bind:
      task_id: current.res.body.id

  list_tasks:
    req:
      /tasks:
        get:
          headers:
            Authorization: "Bearer {{ vars.token }}"
    test: |
      current.res.status == 200
      len(current.res.body.items) >= 1

  get_task:
    req:
      /tasks/{{ vars.task_id }}:
        get:
          headers:
            Authorization: "Bearer {{ vars.token }}"
    test: |
      current.res.status == 200
      current.res.body.id == vars.task_id

  update_task:
    req:
      /tasks/{{ vars.task_id }}:
        patch:
          headers:
            Authorization: "Bearer {{ vars.token }}"
          body:
            application/json:
              title: "更新済みタスク"
    test: |
      current.res.status == 200
      current.res.body.title == "更新済みタスク"

  delete_task:
    req:
      /tasks/{{ vars.task_id }}:
        delete:
          headers:
            Authorization: "Bearer {{ vars.token }}"
    test: current.res.status == 204
```

---

## 実行方法

### DBクエリテスト

```bash
# docker環境内でDBに接続できる状態で実行
cd api
go test ./internal/repository/... -v
```

### E2Eテスト

```bash
# APIサーバーを起動した状態で実行
cd api
go test ./e2e/... -v
```

---

## WebSocketテスト（未実装・追加予定）

### 前提

現時点では handler から `hub.Broadcast()` が呼ばれていないため、WebSocketテストは対象外。
broadcast がハンドラに実装された時点でこのセクションを具体化する。

### テスト対象

| テスト内容 | 確認内容 |
|---|---|
| `/ws?token=...` への接続 | 有効なJWTで接続できる |
| 無効トークンは拒否 | tokenなし/不正tokenで401が返る |
| タスク操作時のイベント受信 | 作成・更新・削除時に接続中クライアントへイベントが届く |

### テスト手段

`gorilla/websocket` のクライアントをGoテストコード内で立て、`httptest.NewServer` で起動したサーバーに接続してイベントを受信確認する。runnはWebSocketに対応していないため、Goのテストコードで実装する。
