# やりたいこと機能 設計書

対応要件定義: [wishes-specification.md](./wishes-specification.md)

本書は、要件定義で決まった「やりたいこと」機能を実装するための**具体的なファイル構成・関数シグネチャ・SQL クエリ・テスト計画・実装順序**を定めるものである。要件に書かれた「何を作るか」はここでは繰り返さず、「どう作るか」だけを書く。

---

## 1. 既存実装の前提と差異の確認

実装前に確定すべき、コードベースの現状と要件との齟齬・抜け漏れ。

### 1.1 WebSocket ブロードキャストは現時点で未配線

[hub.go](../api/internal/websocket/hub.go) に `Hub.Broadcast` インターフェイスは定義され、[websocket_provider.dart:18-29](../app/lib/presentation/providers/websocket_provider.dart#L18-L29) のクライアントは `task.created` 等を受信する前提で分岐を持つ。しかし **Go 側のどの handler も `h.hub.Broadcast(...)` を呼んでいない**（`rg '\.Broadcast\('` → 0 件）。既存のタスク作成でも WS イベントは飛ばない。

要件定義 7 章で「やりたいこと更新で WS 通知する」と書いているが、**既存タスクも実は通知していない**ため、本機能で先行実装すると動作は正しい一方で「既存タスクと同様」とは言えなくなる。

**方針（本機能のスコープ）**: やりたいこと CRUD で `hub.Broadcast` 呼び出しを**実装する**。既存タスクの broadcast 抜けはスコープ外で別 Issue にする。Flutter 側は [websocket_provider.dart](../app/lib/presentation/providers/websocket_provider.dart) に `wish.created/updated/deleted` と `wish_label.created/updated/deleted` の分岐を追加するだけでよい。

### 1.2 エンドポイント名の規約

既存の route は全て小文字の単一単語（`/tasks` `/tags` `/statuses` `/priorities`）。本機能の「ラベル」は複合語なので規約が無い。

**方針**: OpenAPI の一般慣習に合わせ **`/wish-labels`**（kebab-case）。TypeSpec 側は `@route("/wish-labels")` と指定する。

### 1.3 sqlc の `emit_pointers_for_null_types: true`

[sqlc.yaml](../api/sqlc.yaml) で nullable カラムは `*T` になる（例: `memo *string`）。`detail` もこれに従う。

### 1.3.1 Update セマンティクス: PUT（全置換）を採用

既存の tasks/tags/statuses/priorities は **PATCH**（部分更新、`COALESCE(sqlc.narg, col)`）を採用している。本機能の wish は **PUT（全置換）** にする。

**採用理由**:
- `detail` は nullable。PATCH の `narg` では「NULL に設定する」を「変更しない」と区別できないため迂回策が必要になる（narg の代わりに arg を使う・現行値を読み直すなど）
- 編集フォームは常にエンティティ全体を保持しているので、クライアントが全フィールドを送るコストはほぼゼロ
- `labelIds` 全置換は tasks 側でも実質的に `SetTaskTags` + 再 Insert で行っており、PUT と整合性が良い

**トレードオフ**: 既存エンドポイントと HTTP メソッドが混在する（wishes だけ PUT）。記法の統一性より、本機能固有の実装簡素化を優先する。

### 1.4 既存 SQL パターン

- `ListTasks` は `LEFT JOIN task_tags` + `ARRAY_AGG(...) FILTER(...)` で 1 クエリに集約（[tasks.sql:1-12](../api/internal/db/queries/tasks.sql#L1-L12)）。同パターンを wishes に適用する。
- タグ集合の更新は `SetTaskTags`（全 DELETE）→ `InsertTaskTag` を N 回（[tasks.sql:45-50](../api/internal/db/queries/tasks.sql#L45-L50)）。これは tasks 側が PATCH セマンティクスでアプリ側ループになっている事情によるもの。wish は PUT 全置換なので **`unnest` を用いた単一 INSERT** に集約する（後述 4.2）。結果としてラベル更新はトランザクションも N ラウンドトリップも不要になる。

### 1.5 Flutter 側テストは未整備

[widget_test.dart](../app/test/widget_test.dart) にスモーク1件のみ、`mocktail` 系は未導入。本機能で初めてまともなテスト土台を導入する（詳細 8 章）。

---

## 2. 追加・変更するファイル一覧

### 2.1 新規作成（手書き）

| 区分 | パス | 役割 |
|---|---|---|
| Spec | `spec/main.tsp`（**追記**） | Wish / WishLabel モデルとオペレーション |
| Schema | `schema.sql`（**追記**） | `wishes` / `wish_labels` / `wish_label_assignments` |
| SQL | [api/internal/db/queries/wishes.sql](../api/internal/db/queries/) | wishes 用クエリ |
| SQL | [api/internal/db/queries/wish_labels.sql](../api/internal/db/queries/) | wish_labels 用クエリ |
| Handler | [api/internal/handler/wishes.go](../api/internal/handler/) | `WishOps*` 5 メソッド |
| Handler | [api/internal/handler/wish_labels.go](../api/internal/handler/) | `WishLabelOps*` 4 メソッド |
| Handler | [api/internal/handler/convert.go](../api/internal/handler/convert.go)（**追記**） | `toAPIWish*`, `toAPIWishLabel` |
| Testfactory | [api/internal/testfactory/wish.go](../api/internal/testfactory/) | `CreateWish` ヘルパー |
| Testfactory | [api/internal/testfactory/wish_label.go](../api/internal/testfactory/) | `CreateWishLabel` ヘルパー |
| Repo test | [api/internal/repository-test/wishes_test.go](../api/internal/repository-test/) | リポジトリ統合テスト |
| Repo test | [api/internal/repository-test/wish_labels_test.go](../api/internal/repository-test/) | リポジトリ統合テスト |
| E2E | [api/e2e/scenarios/wishes.yaml](../api/e2e/scenarios/) | E2E シナリオ |
| E2E | [api/e2e/scenarios/wish_labels.yaml](../api/e2e/scenarios/) | E2E シナリオ |
| Flutter model | `app/lib/domain/models/wish.dart` | Wish エンティティ |
| Flutter model | `app/lib/domain/models/wish_label.dart` | WishLabel エンティティ |
| Flutter repo IF | `app/lib/domain/repositories/wish_repository.dart` | 抽象 |
| Flutter repo IF | `app/lib/domain/repositories/wish_label_repository.dart` | 抽象 |
| Flutter repo impl | `app/lib/data/repositories/wish_repository_impl.dart` | Dio 経由実装 |
| Flutter repo impl | `app/lib/data/repositories/wish_label_repository_impl.dart` | Dio 経由実装 |
| Flutter provider | `app/lib/presentation/providers/wish_provider.dart` | `wishesProvider` / `wishNotifierProvider` / `selectedLabelFilterProvider` |
| Flutter provider | `app/lib/presentation/providers/wish_label_provider.dart` | `wishLabelNotifierProvider` |
| Flutter page | `app/lib/presentation/pages/wish_list/wish_list_page.dart` | 一覧＋フィルタ |
| Flutter page | `app/lib/presentation/pages/wish_list/widgets/label_filter_dropdown.dart` | ラベルフィルタ UI |
| Flutter page | `app/lib/presentation/pages/wish_list/widgets/wish_card.dart` | カード 1 件 |
| Flutter page | `app/lib/presentation/pages/wish_form/wish_form_page.dart` | 追加／編集フォーム |
| Flutter test | `app/test/helpers/test_scope.dart` | `mocktail` セットアップユーティリティ |
| Flutter test | `app/test/presentation/providers/wish_provider_test.dart` | プロバイダ単体 |
| Flutter test | `app/test/presentation/providers/wish_label_provider_test.dart` | プロバイダ単体 |
| Flutter test | `app/test/presentation/pages/wish_list/wish_list_page_test.dart` | ウィジェットテスト |
| Flutter test | `app/test/presentation/pages/wish_form/wish_form_page_test.dart` | ウィジェットテスト |

### 2.2 既存ファイルの改変

| パス | 変更内容 |
|---|---|
| [app/pubspec.yaml](../app/pubspec.yaml) | `dev_dependencies` に `mocktail: ^1.0.0` を追加 |
| [app/lib/app.dart](../app/lib/app.dart) | `MainShell._pages` と `destinations` に「やりたいこと」を挿入（タスク／やりたいこと／設定の 3 タブ） |
| [app/lib/data/api/api_client.dart](../app/lib/data/api/api_client.dart) | `/wishes` と `/wish-labels` の 9 メソッド追加 |
| [app/lib/presentation/providers/api_provider.dart](../app/lib/presentation/providers/api_provider.dart) | `wishRepositoryProvider`, `wishLabelRepositoryProvider` を追加 |
| [app/lib/presentation/providers/websocket_provider.dart](../app/lib/presentation/providers/websocket_provider.dart) | `wish.*` / `wish_label.*` 分岐を追加 |
| [app/lib/presentation/pages/settings/settings_page.dart](../app/lib/presentation/pages/settings/settings_page.dart) | セクション「ラベル（やりたいこと）」を追加 |

### 2.3 自動生成（手で編集しない）

| 生成元 | 出力 |
|---|---|
| `spec/main.tsp` | `spec/tsp-output/openapi.yaml`, `api/internal/api/oas_*_gen.go` |
| `schema.sql` | `migrator/migrations/20260424*_add_wishes.sql`（Atlas 出力） |
| `api/internal/db/queries/wishes.sql`, `wish_labels.sql` | `api/internal/repository/wishes.sql.go`, `wish_labels.sql.go` + models.go への追記 |

---

## 3. DB 設計（schema.sql）

[schema.sql](../schema.sql) の末尾に以下を追記する。

```sql
CREATE TABLE wishes (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title      TEXT        NOT NULL,
    detail     TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE wish_labels (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);

CREATE TABLE wish_label_assignments (
    wish_id       UUID NOT NULL REFERENCES wishes(id)      ON DELETE CASCADE,
    wish_label_id UUID NOT NULL REFERENCES wish_labels(id) ON DELETE CASCADE,
    PRIMARY KEY (wish_id, wish_label_id)
);
```

マイグレーションの作成は動作確認後に行う。

---

## 4. API 層

### 4.1 TypeSpec（spec/main.tsp 追記）

既存の Tag セクションの直後（ファイル末尾）に以下を追加する。

```typespec
// ---------------------------------------------------------------------------
// Wishes (やりたいこと)
// ---------------------------------------------------------------------------

model Wish {
  id: string;
  title: string;
  detail: string | null;
  labelIds: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

model WishList { items: Wish[]; }

model CreateWishRequest {
  title: string;
  detail?: string;
  labelIds?: string[];
}

// PUT semantics: full replacement. All fields required.
model UpdateWishRequest {
  title: string;
  detail: string | null;
  labelIds: string[];
}

@route("/wishes")
@tag("Wishes")
@useAuth(BearerAuth)
interface WishOps {
  @get list(): WishList | ApiError;
  @post create(@body body: CreateWishRequest): Wish | ApiError;
  @get  @route("{id}") get(@path id: string): Wish | ApiError;
  @put  @route("{id}") update(@path id: string, @body body: UpdateWishRequest): Wish | ApiError;
  @delete @route("{id}") delete(@path id: string): void | ApiError;
}

// ---------------------------------------------------------------------------
// Wish Labels
// ---------------------------------------------------------------------------

model WishLabel {
  id: string;
  name: string;
}

model WishLabelList { items: WishLabel[]; }

model CreateWishLabelRequest { name: string; }

// PUT semantics: full replacement. `name` required.
model UpdateWishLabelRequest { name: string; }

@route("/wish-labels")
@tag("WishLabels")
@useAuth(BearerAuth)
interface WishLabelOps {
  @get list(): WishLabelList | ApiError;
  @post create(@body body: CreateWishLabelRequest): WishLabel | ApiError;
  @put   @route("{id}") update(@path id: string, @body body: UpdateWishLabelRequest): WishLabel | ApiError;
  @delete @route("{id}") delete(@path id: string): void | ApiError;
}
```

### 4.2 sqlc クエリ

#### `api/internal/db/queries/wish_labels.sql`

[tags.sql](../api/internal/db/queries/tags.sql) と同形。

```sql
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
```

#### `api/internal/db/queries/wishes.sql`

[tasks.sql](../api/internal/db/queries/tasks.sql) と同形。

```sql
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
-- PUT semantics: full replacement. Client always sends title and detail
-- (detail can be NULL to clear).
UPDATE wishes SET
    title      = $3,
    detail     = $4,
    updated_at = NOW()
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
```

ラベル更新は `ClearWishLabels` → `ReplaceWishLabels` の 2 クエリで完結する。PUT 全置換なので `COALESCE` や `narg`/`arg` の分岐は不要。アプリ側ループ（N ラウンドトリップ）も発生しないため、**明示的なトランザクション化は不要**（FK 違反は `ReplaceWishLabels` の INSERT で検出される。間に他リクエストが割り込んでも影響するのは自分の wish の assignments だけで、最終的な全置換結果は変わらない）。結果として `Handler` への `*pgxpool.Pool` 注入は不要で、既存の `*repository.Queries` 注入のまま実装できる。

### 4.3 Handler 実装

#### `api/internal/handler/wish_labels.go`

[tags.go](../api/internal/handler/tags.go) のコピーに近い。4 メソッド。

```go
func (h *Handler) WishLabelOpsList(ctx context.Context) (*api.WishLabelList, error)
func (h *Handler) WishLabelOpsCreate(ctx context.Context, req *api.CreateWishLabelRequest) (*api.WishLabel, error)
func (h *Handler) WishLabelOpsUpdate(ctx context.Context, req *api.UpdateWishLabelRequest, params api.WishLabelOpsUpdateParams) (*api.WishLabel, error)
func (h *Handler) WishLabelOpsDelete(ctx context.Context, params api.WishLabelOpsDeleteParams) error
```

各メソッドの末尾で `h.hub.Broadcast(userID, websocket.Event{Type: "wish_label.created", Payload: toAPIWishLabel(row)})` を呼ぶ。

#### `api/internal/handler/wishes.go`

[tasks.go](../api/internal/handler/tasks.go) を参考に。5 メソッド。

- **Create**: `CreateWish` → `ReplaceWishLabels`（空配列でも安全）。最後に `hub.Broadcast("wish.created", wishWithLabels)`。
- **Update (PUT)**: `UpdateWish`（title/detail 全置換）→ `ClearWishLabels` → `ReplaceWishLabels`。`wish.updated` をブロードキャスト。
- **Delete**: `DeleteWish`。`wish.deleted` をブロードキャスト（ペイロードは `{id}`）。
- **List/Get**: 単純な読み出し。ブロードキャストなし。

いずれも明示的トランザクションは使わない（理由は 4.2 末尾）。

**バリデーション**（要件定義 6.4 に対応）:
- `req.Title` を `strings.TrimSpace` で空文字チェック → 400
- `req.Title` に `\n` or `\r` が含まれていたら → 400
- `req.LabelIds` の UUID パース失敗 → 400
- 存在しない label_id → DB の FK 違反が戻るので、ハンドラで 400 に変換する
- PUT は「リソース全体を送る」契約なので、title/detail/labelIds の欠落は ogen の自動バリデーションで 400 になる（個別処理は不要）

ラベル更新が `unnest` 一括 INSERT になったため、ハンドラへの `*pgxpool.Pool` 注入は不要。既存の `*repository.Queries` 注入のまま実装する。

#### `api/internal/handler/convert.go` 追記

```go
func toAPIWishLabel(l repository.WishLabel) *api.WishLabel {
    return &api.WishLabel{ID: l.ID.String(), Name: l.Name}
}

// Wish 本体と labelIds を受けて api.Wish を組み立てる単一関数。
// List / Get / Create / Update すべての呼び出し元で使い回す。
func toAPIWish(w repository.Wish, labelIds []uuid.UUID) api.Wish { /* ... */ }
```

List/Get は sqlc が `ListWishesRow` / `GetWishRow` を別型で吐くが、呼び出し側で `row.Wish` と `row.LabelIds` に分解して `toAPIWish` に渡せば 1 関数で足りる。`detail` は nullable なので [convert.go:89-94](../api/internal/handler/convert.go#L89-L94) の `nilStringFromPtr` を流用する。

### 4.4 WebSocket ブロードキャスト

ハンドラの各ミューテーションで `h.hub.Broadcast(userID, websocket.Event{...})` を呼ぶ（1.1 で決めた方針）。

**イベント種別は集約する**。要件書 7 章では `wish.created/updated/deleted` と `wish_label.created/updated/deleted` の 6 種が案として挙げられているが、クライアントの対応はどのケースも「該当 provider を invalidate するだけ」なので、サーバもクライアントもイベント種別を分ける利点が無い。以下の 2 種に集約する。

| メソッド | イベント Type | Payload |
|---|---|---|
| `WishOpsCreate` / `Update` / `Delete` | `wish.changed` | `{}` |
| `WishLabelOpsCreate` / `Update` / `Delete` | `wish_label.changed` | `{}` |

Flutter 側は `wish.changed` で `wishesProvider` を、`wish_label.changed` で `wishLabelNotifierProvider` を invalidate するだけ。将来、楽観更新などでペイロードが必要になったタイミングで分割やペイロード追加を検討する（YAGNI）。要件書 7 章の「6 種イベント」記述は本設計に合わせて更新する。

---

## 5. Flutter クライアント

### 5.1 domain 層

#### `app/lib/domain/models/wish.dart`

```dart
class Wish {
  final String id;
  final String title;
  final String? detail;
  final List<String> labelIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wish({
    required this.id,
    required this.title,
    this.detail,
    this.labelIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Wish copyWith({ /* ... */ });
}
```

#### `app/lib/domain/models/wish_label.dart`

Tag と同形で name/id のみ。

#### `app/lib/domain/repositories/wish_repository.dart`

```dart
abstract class WishRepository {
  Future<List<Wish>> getWishes();
  Future<Wish> addWish({
    required String title,
    String? detail,
    List<String> labelIds = const [],
  });
  // PUT semantics: caller supplies the full new state.
  // `detail: null` means "clear detail".
  Future<Wish> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
  });
  Future<void> deleteWish(String id);
}
```

#### `app/lib/domain/repositories/wish_label_repository.dart`

`TagRepository` と同形。

### 5.2 data 層

#### `api_client.dart` への追加（9 メソッド）

`/wishes` は GET / GET(id) / POST / **PUT**(id) / DELETE の 5 本、`/wish-labels` は GET / POST / **PUT**(id) / DELETE の 4 本。既存の [api_client.dart:168-199](../app/lib/data/api/api_client.dart#L168-L199) を参考にしつつ、update 部分は `_dio.put(...)` を使う（既存 tag/task は `_dio.patch(...)`）。

#### `wish_repository_impl.dart` / `wish_label_repository_impl.dart`

[tag_repository_impl.dart](../app/lib/data/repositories/tag_repository_impl.dart) と同じ構造。JSON パースで `detail` が null の場合の扱いを注意する。

### 5.3 presentation 層

#### `wish_label_provider.dart`

[tag_provider.dart](../app/lib/presentation/providers/tag_provider.dart) と同形の `AsyncNotifier<List<WishLabel>>`。`findOrCreate`, `edit`, `delete` を提供。

#### `wish_provider.dart`

```dart
// 選択中のラベルフィルタ（null = 「すべて」）
final selectedWishLabelFilterProvider = StateProvider<String?>((ref) => null);

// 生のやりたいこと一覧（サーバから）
final wishesProvider = FutureProvider<List<Wish>>((ref) async {
  final repo = ref.watch(wishRepositoryProvider);
  return repo.getWishes();
});

// フィルタ適用済み一覧（UI はこちらを watch）
final filteredWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    if (labelId == null) return list;
    return list.where((w) => w.labelIds.contains(labelId)).toList();
  });
});

class WishNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addWish({...}) async { ... ; ref.invalidate(wishesProvider); }
  Future<void> updateWish({...}) async { ... ; ref.invalidate(wishesProvider); }
  Future<void> deleteWish(String id) async { ... ; ref.invalidate(wishesProvider); }
}
```

**削除時のフィルタ整合性**: ラベルが削除されたときに `selectedWishLabelFilterProvider` がそのラベルを指している可能性がある。`wishLabelNotifierProvider` の削除 API 成功後に、フィルタ state が削除 ID と一致していれば null に戻す。

#### 画面構造

- `wish_list_page.dart` — AppBar: 「やりたいこと」、body: `LabelFilterDropdown` + 一覧（`ListView.builder`）、FAB: `+` で `WishFormPage()` へ遷移
- `wish_list/widgets/label_filter_dropdown.dart` — `DropdownButtonFormField<String?>` で `null` が「すべて」
- `wish_list/widgets/wish_card.dart` — タイトル（太字）、詳細（あれば `maxLines: 2, overflow: ellipsis`）、ラベルの `Wrap<Chip>`、相対時刻
- `wish_form/wish_form_page.dart` — [task_form_page.dart](../app/lib/presentation/pages/task_form/task_form_page.dart) を雛形に、以下を変更:
  - タイトル: `TextFormField(maxLines: 1, inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))])`
  - 詳細: `TextFormField(maxLines: null, minLines: 3)`
  - 優先度・ステータス・期限日セクションを削除
  - ラベル入力は既存のタグ入力 Autocomplete をそのまま流用（`tagNotifier` → `wishLabelNotifier`）

### 5.4 MainShell

[app.dart:62-77](../app/lib/app.dart#L62-L77) を次のように変える。

```dart
final _pages = const [
  TaskListPage(),
  WishListPage(),
  SettingsPage(),
];
// destinations に:
NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: 'やりたいこと'),
```

アイコンは `Icons.lightbulb_outline` を採用（`Icons.star_outline` は「お気に入り」連想が強い）。

### 5.5 WebSocket

[websocket_provider.dart:18-29](../app/lib/presentation/providers/websocket_provider.dart#L18-L29) の `switch` に追記する。

```dart
case 'wish.changed':
  ref.invalidate(wishesProvider);
case 'wish_label.changed':
  ref.invalidate(wishLabelNotifierProvider);
```

### 5.6 設定画面（ラベル管理）

[settings_page.dart](../app/lib/presentation/pages/settings/settings_page.dart) の `_SectionHeader('タグ')` の直下に `_SectionHeader('ラベル（やりたいこと）')` と `_WishLabelSettings()` を追加する。構造は `_TagSettings` をコピー。

---

## 6. 実装順序（PR 分割の推奨単位）

段階ごとにコミット可能で、ビルドと test-generated.yml が通る単位で区切る。

### ステップ 1 — スキーマと生成物（約 30 分）

1. `schema.sql` に 3 テーブル追加
2. `spec/main.tsp` に Wish/WishLabel を追加
3. `api/internal/db/queries/wishes.sql` と `wish_labels.sql` を作成
4. `mise run gen` を実行 → openapi.yaml / oas_*_gen.go / repository/*.sql.go が生成される
5. `mise run db:migrations:create` → migrator/migrations/* と atlas.sum が更新される
6. `go build ./...` で API がコンパイル通ることを確認（ハンドラ未実装なので `ogen_unimplemented` が呼ばれる状態だが build は通る）

### ステップ 2 — API ハンドラ本体（約 1 日）

1. `Handler` 構造体に `pool *pgxpool.Pool` を追加、`main.go` の呼び出しを更新
2. `handler/convert.go` に変換関数を追記
3. `handler/wish_labels.go` 実装（Broadcast 含む）
4. `handler/wishes.go` 実装（トランザクション + Broadcast）
5. `testfactory/wish.go`, `wish_label.go` 作成
6. `repository-test/wishes_test.go`, `wish_labels_test.go` 作成
7. `cd api && go test ./...` が通ることを確認

### ステップ 3 — E2E（約 30 分）

1. `e2e/scenarios/wishes.yaml`, `wish_labels.yaml` 作成（[tags.yaml](../api/e2e/scenarios/tags.yaml) 参考）
2. `docker compose up -d` の状態で `cd api && go test ./e2e/...` が通ることを確認

### ステップ 4 — Flutter: テスト土台整備（約 30 分、8 章参照）

1. `pubspec.yaml` に `mocktail` 追加 → `flutter pub get`
2. `app/test/helpers/test_scope.dart` 作成（リポジトリの `ProviderScope.overrides` ユーティリティ）

### ステップ 5 — Flutter: data / domain（約 2 時間）

1. model / repository IF / repository impl 追加
2. `api_client.dart` に 9 メソッド追加
3. `api_provider.dart` に 2 プロバイダ追加
4. ここまでで `flutter analyze` がクリーンであること

### ステップ 6 — Flutter: presentation（約 半日）

1. `wish_label_provider.dart`, `wish_provider.dart` 作成
2. 画面 3 つ（list / form / label settings セクション）
3. `app.dart` の NavigationBar に追加
4. `websocket_provider.dart` に分岐追加
5. `settings_page.dart` にラベル管理セクション追加

### ステップ 7 — Flutter テスト（約 半日、8 章参照）

### ステップ 8 — 動作確認

1. `docker compose up -d`
2. Flutter デスクトップ（Windows/macOS/Linux のどれか）で実機起動
3. やりたいこと追加→詳細あり/なし→編集→ラベル付与→フィルタ→ラベル削除で付与が外れることを目視確認
4. 2 クライアント同時起動で WS 同期を確認

---

## 7. API テスト計画（Go 側）

### 7.1 repository-test

[tags_test.go](../api/internal/repository-test/tags_test.go) に準じて作成。最低限以下をカバー:

**wish_labels_test.go**
- `Create` / `List`（name 昇順）/ `Get` / `Update` / `Delete`
- `List_OtherUserIsolation`（他ユーザーのラベルが見えないこと）
- `Create_DuplicateName` → unique 制約違反エラー（同一 user_id 内）
- `Create_SameNameDifferentUser` → 成功

**wishes_test.go**
- `Create` / `List` / `Get` / `Update` / `Delete`
- `List_OrdersByCreatedAtDesc`
- `List_IncludesLabelIds`（JOIN 集約の検証）
- `Update_ReplacesDetail`（PUT セマンティクス: detail を別の値に差し替える）
- `Update_ClearsDetailWhenNullGiven`（PUT で detail NULL を渡すと NULL になる）
- `Label_CascadeOnWishDelete`（wish 削除で assignments が消える）
- `Label_CascadeOnWishLabelDelete`（wish_label 削除で assignments のみ消える、wish 本体は残る）
- `Create_DetailCanBeNull`

### 7.2 E2E（runn）

[tags.yaml](../api/e2e/scenarios/tags.yaml) に準じる。

**wishes.yaml**
- `create_wish_label` → `create_wish` (labelIds 指定) → `list_wishes`（labelIds が含まれている）→ `update_wish` (PUT、detail を null にして全置換) → `delete_wish`

**wish_labels.yaml**
- `create_wish_label` → `list` → `update_wish_label` (PUT、改名) → `delete_wish_label`

---

## 8. Flutter テスト計画

### 8.1 導入する dev 依存

[pubspec.yaml](../app/pubspec.yaml) に追加:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.12.2
  riverpod_generator: ^4.0.3
  mocktail: ^1.0.0   # ← 追加
```

Dio/HTTP のスタブは**リポジトリ層でモック**する方針（`ApiClient` を触らない）。これでネット層・JSON パース差分の影響を受けずに済む。

### 8.2 共通ヘルパー `app/test/helpers/test_scope.dart`

```dart
// WishRepository / WishLabelRepository のモック登録
// ProviderContainer を作り、provider を override するユーティリティ
ProviderContainer makeContainer({
  required WishRepository wishRepo,
  required WishLabelRepository wishLabelRepo,
}) { ... }
```

### 8.3 プロバイダテスト（`app/test/presentation/providers/`）

**wish_provider_test.dart**
- `wishesProvider` が `repo.getWishes()` の結果を返す
- `filteredWishesProvider` が null フィルタで全件、ラベル指定で該当ラベル付きのみ
- `WishNotifier.addWish` が repo を呼び invalidate される
- `WishNotifier.deleteWish` 同上

**wish_label_provider_test.dart**
- `findOrCreate`: 既存名がある場合は既存 ID を返し API を叩かない
- `findOrCreate`: 新規名は API を叩いて invalidate
- `delete` 後、`selectedWishLabelFilterProvider` がそのラベルを指していたら null に戻る（この連動が本当に必要かは 5.3 で再検討）

### 8.4 ウィジェットテスト（`app/test/presentation/pages/`）

**wish_list_page_test.dart**
- 空状態メッセージが出る
- やりたいこと 2 件を与えると両方が描画される
- ラベルフィルタに `null`（すべて）→ 2 件、特定ラベル → 該当 1 件、に絞られる
- FAB タップで `WishFormPage` に遷移する（`Navigator` のモックで検証）

**wish_form_page_test.dart**
- 新規モード: タイトル空なら保存ボタンがタップされても repo が呼ばれない（バリデーション）
- タイトルに改行を含めようとしても `inputFormatters` で弾かれる
- 詳細を空で保存できる
- 編集モード: 既存値が initialValue に載っている
- ラベル Chip を選択→保存時に `labelIds` に含まれる

### 8.5 スコープ外（本フェーズでやらない）

- 既存タスクのウィジェットテスト
- `ApiClient` / `Dio` の直接テスト（リポジトリ層モックで十分なため）
- Integration Test（`integration_test/` ディレクトリそのものを今回は作らない）

---

## 9. オープンな決定事項（実装前に確定したいもの）

| # | 項目 | 現在の方針 | 備考 |
|---|---|---|---|
| 1 | WS イベントの粒度 | `wish.changed` / `wish_label.changed` の 2 種に集約（4.4 参照） | 要件書 7 章（6 種案）は本設計に合わせて更新 |
| 2 | 既存タスクの WS ブロードキャスト不在 | 本機能のスコープ外で別 Issue | wishes 実装後に気付いた差異を issue 化しておく |
| 3 | ラベル削除時のフィルタ state 連動 | `WishLabelNotifier.delete` 内で `selectedWishLabelFilterProvider` を触る | プロバイダ間依存が増えるが挙動としては自然 |
| 4 | mocktail のバージョン | `^1.0.0` | 実装時に最新安定版を確認する |

---

## 10. リスクと回避策

| リスク | 回避策 |
|---|---|
| WS ブロードキャスト新規追加で既存 E2E が壊れる | `hub` は LocalHub、WS 接続がなければ no-op。E2E は HTTP のみなので影響なし |
| PUT で古いクライアントが新フィールド未送信のまま PUT してフィールドを消す | 本機能は新規なので「古いクライアント」が存在しない。将来フィールドを追加する際は PATCH への切り替え or API バージョニングを別途検討 |
| PUT による Lost Update（2 人が同時に編集→後勝ちで消える） | 本フェーズでは許容（単一ユーザーのマルチデバイス想定）。楽観ロック（`If-Match` / `updated_at` チェック）は将来検討 |
| マイグレーション適用時の既存テンプレート DB (`taskmanager_template`) | `mise run db:migrate` で適用し直す。README の手順に従えば自動で取り込まれる |
| Flutter のアイコン見た目が Android/iOS/Desktop で崩れる | 実装後に各プラットフォームで 1 度起動して確認 |
