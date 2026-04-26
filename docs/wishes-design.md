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
- `detail` と `archivedAt` は nullable。PATCH の `narg` では「NULL に設定する」を「変更しない」と区別できないため迂回策が必要になる（narg の代わりに arg を使う・現行値を読み直すなど）
- 編集フォームは常にエンティティ全体を保持しているので、クライアントが全フィールドを送るコストはほぼゼロ
- `labelIds` 全置換は tasks 側でも実質的に `SetTaskTags` + 再 Insert で行っており、PUT と整合性が良い
- アーカイブ／復元も PUT の同じトランザクションで `archivedAt` を `now` または `null` に差し替えるだけで完結し、専用エンドポイント（`POST /wishes/{id}/archive` 等）を作らずに済む

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
| Flutter page | `app/lib/presentation/pages/wish_list/wish_list_page.dart` | 通常一覧＋フィルタ＋AppBar からアーカイブ画面導線 |
| Flutter page | `app/lib/presentation/pages/wish_list/wish_archive_page.dart` | アーカイブ専用画面（一覧＋フィルタ、FAB なし） |
| Flutter page | `app/lib/presentation/pages/wish_list/widgets/label_filter_dropdown.dart` | ラベルフィルタ UI（通常／アーカイブ画面で共用） |
| Flutter page | `app/lib/presentation/pages/wish_list/widgets/wish_card.dart` | カード 1 件（通常／アーカイブの表示モード切替） |
| Flutter page | `app/lib/presentation/pages/wish_list/widgets/swipeable_wish_card.dart` | `Dismissible` でラップ。左スワイプでアーカイブ／復元 |
| Flutter page | `app/lib/presentation/pages/wish_form/wish_form_page.dart` | 追加／編集フォーム（アーカイブ済みも編集可） |
| Flutter test | `app/test/helpers/test_scope.dart` | `mocktail` セットアップユーティリティ |
| Flutter test | `app/test/presentation/providers/wish_provider_test.dart` | プロバイダ単体 |
| Flutter test | `app/test/presentation/providers/wish_label_provider_test.dart` | プロバイダ単体 |
| Flutter test | `app/test/presentation/pages/wish_list/wish_list_page_test.dart` | ウィジェットテスト |
| Flutter test | `app/test/presentation/pages/wish_list/wish_archive_page_test.dart` | アーカイブ画面ウィジェットテスト |
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
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    detail      TEXT,
    archived_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
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

`archived_at` は NULL 可（NULL = 通常状態、値あり = アーカイブ済み）。専用のインデックスは設けない（一覧クエリは `user_id` でのスキャン後に GROUP BY であり、アーカイブ／通常の振り分けはアプリ層／クライアント側で行う）。データ件数が増えて問題になった時点で部分インデックス `WHERE archived_at IS NULL` を検討する。

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
  archivedAt: utcDateTime | null;
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
// archivedAt: null = 通常、値あり = アーカイブ済み。
// アーカイブ／復元はこのフィールドの差し替えで表現する（専用エンドポイントなし）。
model UpdateWishRequest {
  title: string;
  detail: string | null;
  labelIds: string[];
  archivedAt: utcDateTime | null;
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
-- 新規作成時は常に通常状態（archived_at = NULL）。
INSERT INTO wishes (user_id, title, detail) VALUES ($1, $2, $3) RETURNING *;

-- name: UpdateWish :one
-- PUT semantics: full replacement. Client always sends title, detail, archived_at
-- (各 NULL を渡せば NULL になる)。アーカイブ＝archived_at に時刻、復元＝archived_at に NULL。
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
```

ラベル更新は `ClearWishLabels` → `ReplaceWishLabels` の 2 クエリで完結する。PUT 全置換なので `COALESCE` や `narg`/`arg` の分岐は不要。アプリ側ループ（N ラウンドトリップ）も発生しないため、**明示的なトランザクション化は不要**（FK 違反は `ReplaceWishLabels` の INSERT で検出される。間に他リクエストが割り込んでも影響するのは自分の wish の assignments だけで、最終的な全置換結果は変わらない）。結果として `Handler` への `*pgxpool.Pool` 注入は不要で、既存の `*repository.Queries` 注入のまま実装できる。

**アーカイブ／通常の振り分けはクエリで行わない**。`ListWishes` はアーカイブ済みも含む全件を返し、通常一覧画面とアーカイブ画面はクライアント側で `archivedAt` の null 判定で絞り込む（要件定義 4.4）。専用の `ListArchivedWishes` 等のクエリは作らない。これにより:
- WS で `wish.changed` を受けたとき、両画面が同じプロバイダのキャッシュを参照しているので 1 回の再フェッチで両方の画面が更新される
- アーカイブ→通常への復元アニメーション中も、同一データセット内の遷移として扱える

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

- **Create**: `CreateWish` → `ReplaceWishLabels`（空配列でも安全）。`archived_at` は常に NULL（新規作成は通常状態）。最後に `hub.Broadcast("wish.changed", {})`。
- **Update (PUT)**: `UpdateWish`（title / detail / archived_at 全置換）→ `ClearWishLabels` → `ReplaceWishLabels`。`wish.changed` をブロードキャスト。アーカイブ・復元・通常編集のいずれもこの 1 経路で処理される（クライアントが `archivedAt` フィールドに時刻を入れるか null を入れるかの差だけ）。
- **Delete**: `DeleteWish`。`wish.changed` をブロードキャスト。アーカイブ済みの行も同じ経路で削除される。
- **List/Get**: 単純な読み出し。ブロードキャストなし。`archived_at` は通常／アーカイブの区別なくレスポンスに含める。

いずれも明示的トランザクションは使わない（理由は 4.2 末尾）。

**バリデーション**（要件定義 6.4 に対応）:
- `req.Title` を `strings.TrimSpace` で空文字チェック → 400
- `req.Title` に `\n` or `\r` が含まれていたら → 400
- `req.LabelIds` の UUID パース失敗 → 400
- 存在しない label_id → DB の FK 違反が戻るので、ハンドラで 400 に変換する
- `req.ArchivedAt` は受信した時刻をそのまま保存する（未来日チェック等はしない）。null は許容
- PUT は「リソース全体を送る」契約なので、title/detail/labelIds/archivedAt の欠落は ogen の自動バリデーションで 400 になる（個別処理は不要）

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

List/Get は sqlc が `ListWishesRow` / `GetWishRow` を別型で吐くが、呼び出し側で `row.Wish` と `row.LabelIds` に分解して `toAPIWish` に渡せば 1 関数で足りる。`detail` および `archived_at` は nullable なので [convert.go:89-94](../api/internal/handler/convert.go#L89-L94) の `nilStringFromPtr` / 既存の時刻 nullable ヘルパを流用する。

### 4.4 WebSocket ブロードキャスト

ハンドラの各ミューテーションで `h.hub.Broadcast(userID, websocket.Event{...})` を呼ぶ（1.1 で決めた方針）。

**イベント種別は集約する**。要件書 7 章では `wish.created/updated/deleted` と `wish_label.created/updated/deleted` の 6 種が案として挙げられているが、クライアントの対応はどのケースも「該当 provider を invalidate するだけ」なので、サーバもクライアントもイベント種別を分ける利点が無い。以下の 2 種に集約する。

| メソッド | イベント Type | Payload |
|---|---|---|
| `WishOpsCreate` / `Update` / `Delete` | `wish.changed` | `{}` |
| `WishLabelOpsCreate` / `Update` / `Delete` | `wish_label.changed` | `{}` |

アーカイブ／復元も「Update の中で `archived_at` が変わるだけ」なので、専用イベントは作らず `wish.changed` を再利用する（要件定義 4.7「通知: アーカイブ／復元時も `wish.changed` で他端末に通知（個別イベントは作らない）」と整合）。

Flutter 側は `wish.changed` で `wishesProvider` を、`wish_label.changed` で `wishLabelNotifierProvider` を invalidate するだけ。`activeWishesProvider` / `archivedWishesProvider` は `wishesProvider` の派生なので、この 1 回の invalidate で通常画面・アーカイブ画面の両方が同時に再描画される。将来、楽観更新などでペイロードが必要になったタイミングで分割やペイロード追加を検討する（YAGNI）。要件書 7 章の「6 種イベント」記述は本設計に合わせて更新する。

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
  final DateTime? archivedAt; // null = 通常、値あり = アーカイブ済み
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wish({
    required this.id,
    required this.title,
    this.detail,
    this.labelIds = const [],
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  Wish copyWith({ /* ... archivedAt も含む。null へのリセットは「未指定」と区別するために
                     copyWithArchivedAtNull() のような専用メソッド or sentinel を使う ... */ });
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
  // `detail: null` means "clear detail". `archivedAt: null` means "通常状態", 値ありは "アーカイブ済み"。
  // アーカイブ／復元もこのメソッド 1 本で扱い、専用 archive()/unarchive() は設けない。
  Future<Wish> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
    required DateTime? archivedAt,
  });
  Future<void> deleteWish(String id);
}
```

`updateWish` の `archivedAt` パラメータは「現在値そのまま」を表現できないため、呼び出し元は常に意図を持って null か値を渡す（PUT 全置換のため）。スワイプによるアーカイブ／復元では既存値を利用しないので問題にならない。通常編集（フォーム保存）では「フォームを開いた時点の archivedAt をそのまま送る」運用とする。

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
// 選択中のラベルフィルタ（null = 「すべて」）。通常画面とアーカイブ画面で共有する。
final selectedWishLabelFilterProvider = StateProvider<String?>((ref) => null);

// 生のやりたいこと一覧（サーバから）。通常／アーカイブ済みの両方を含む。
final wishesProvider = FutureProvider<List<Wish>>((ref) async {
  final repo = ref.watch(wishRepositoryProvider);
  return repo.getWishes();
});

// 通常一覧（archivedAt == null）。作成日時降順。UI はこちらを watch。
final activeWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    final active = list.where((w) => !w.isArchived);
    final filtered = labelId == null
        ? active
        : active.where((w) => w.labelIds.contains(labelId));
    return filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

// アーカイブ一覧（archivedAt != null）。アーカイブ日時降順。
final archivedWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    final archived = list.where((w) => w.isArchived);
    final filtered = labelId == null
        ? archived
        : archived.where((w) => w.labelIds.contains(labelId));
    return filtered.toList()
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
  });
});

class WishNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addWish({...}) async { ... ; ref.invalidate(wishesProvider); }
  Future<void> updateWish({...}) async { ... ; ref.invalidate(wishesProvider); }
  Future<void> deleteWish(String id) async { ... ; ref.invalidate(wishesProvider); }

  // スワイプによるアーカイブ／復元用ショートカット。
  // 内部で対象 wish の他フィールドを保ったまま archivedAt のみ書き換えて PUT する。
  Future<void> archiveWish(Wish target) async {
    await _repo.updateWish(
      id: target.id,
      title: target.title,
      detail: target.detail,
      labelIds: target.labelIds,
      archivedAt: DateTime.now().toUtc(),
    );
    ref.invalidate(wishesProvider);
  }

  Future<void> restoreWish(Wish target) async {
    await _repo.updateWish(
      id: target.id,
      title: target.title,
      detail: target.detail,
      labelIds: target.labelIds,
      archivedAt: null,
    );
    ref.invalidate(wishesProvider);
  }
}
```

**Undo の実装**: `archiveWish` / `restoreWish` を呼んだ画面側で `SnackBarAction` の `onPressed` から逆操作（`restoreWish` / `archiveWish`）を呼ぶ。Notifier は最新値だけを扱い、Undo の状態は画面ローカルに留める（一覧の再描画と Undo 操作の両立を単純化するため）。

**削除時のフィルタ整合性**: ラベルが削除されたときに `selectedWishLabelFilterProvider` がそのラベルを指している可能性がある。`wishLabelNotifierProvider` の削除 API 成功後に、フィルタ state が削除 ID と一致していれば null に戻す。通常画面・アーカイブ画面のどちらで開いていても同じ `selectedWishLabelFilterProvider` を共有しているため、この処理は 1 箇所で済む。

#### 画面構造

- `wish_list_page.dart` — AppBar: 「やりたいこと」、AppBar 右上に `IconButton(Icons.inventory_2_outlined)` でアーカイブ画面 (`WishArchivePage`) へ遷移、body: `LabelFilterDropdown` + 通常一覧（`activeWishesProvider` を watch）、FAB: `+` で `WishFormPage()` へ遷移
- `wish_archive_page.dart` — AppBar: 「アーカイブ」（戻る矢印で通常画面へ）、body: `LabelFilterDropdown` + アーカイブ一覧（`archivedWishesProvider` を watch）、FAB なし
- `wish_list/widgets/label_filter_dropdown.dart` — `DropdownButtonFormField<String?>` で `null` が「すべて」。通常画面・アーカイブ画面で共有
- `wish_list/widgets/wish_card.dart` — タイトル（太字）、詳細（あれば `maxLines: 2, overflow: ellipsis`）、ラベルの `Wrap<Chip>`、相対時刻
  - 通常一覧では「作成日時の相対表示」、アーカイブ一覧では「達成: 〜前」を表示する。表示文言の切り替えは `wish.isArchived` と渡されたモード（通常 / アーカイブ）で分岐させる
- `wish_list/widgets/swipeable_wish_card.dart` — `Dismissible` でカードをラップ。
  - `direction: DismissDirection.endToStart`（左方向にスワイプ）
  - `onDismissed`: 通常画面では `wishNotifier.archiveWish(target)`、アーカイブ画面では `wishNotifier.restoreWish(target)` を呼ぶ
  - 直後に `ScaffoldMessenger.of(context).showSnackBar(...)` で「アーカイブしました／元に戻しました」を表示し、`SnackBarAction` で逆操作を提供
  - `key` は `ValueKey(wish.id)` を必ず指定（`Dismissible` の `key` 必須要件）
- `wish_form/wish_form_page.dart` — [task_form_page.dart](../app/lib/presentation/pages/task_form/task_form_page.dart) を雛形に、以下を変更:
  - タイトル: `TextFormField(maxLines: 1, inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))])`
  - 詳細: `TextFormField(maxLines: null, minLines: 3)`
  - 優先度・ステータス・期限日セクションを削除
  - ラベル入力は既存のタグ入力 Autocomplete をそのまま流用（`tagNotifier` → `wishLabelNotifier`）
  - **アーカイブ済みでも編集可能**: 編集モードで `wish.isArchived` であってもフォームを通常通り表示・保存可能（要件定義 4.7「編集」）。フォーム上にアーカイブ／復元ボタンは置かず、状態切替はスワイプ UI に集約する
  - **archivedAt の保持**: 編集モードで開いた時点の `wish.archivedAt` をフォーム state に保持し、保存時 `updateWish` にそのまま渡す（通常編集で誤ってアーカイブを解除しないため）
  - **未確定ラベルのガード**: ラベル入力フィールドの `TextEditingController` を保持し、保存ボタン押下時にコントローラのテキストが空でない場合は保存を中断して `SnackBar`（例: `'ラベル名が確定されていません。Enter で確定するか、入力を消去してください。'`）を表示する。`repo` 呼び出しは行わない。

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

1. `wish_label_provider.dart`, `wish_provider.dart` 作成（`activeWishesProvider` / `archivedWishesProvider` / `archiveWish` / `restoreWish` 含む）
2. 画面 4 つ（通常一覧 / アーカイブ / フォーム / 設定のラベル管理セクション）
3. `swipeable_wish_card.dart` で `Dismissible` ラップ・Undo SnackBar を実装
4. `app.dart` の NavigationBar に「やりたいこと」追加
5. `websocket_provider.dart` に `wish.changed` / `wish_label.changed` 分岐追加
6. `settings_page.dart` にラベル管理セクション追加

### ステップ 7 — Flutter テスト（約 半日、8 章参照）

### ステップ 8 — 動作確認

1. `docker compose up -d`
2. Flutter デスクトップ（Windows/macOS/Linux のどれか）で実機起動
3. やりたいこと追加→詳細あり/なし→編集→ラベル付与→フィルタ→ラベル削除で付与が外れることを目視確認
4. 通常画面で左スワイプ→アーカイブ画面に出現→アーカイブ画面で左スワイプ→通常画面に戻ることを確認
5. SnackBar の Undo を押すと操作が取り消されることを確認
6. ラベルフィルタを掛けた状態でアーカイブしても、フィルタが効いていることを確認
7. 2 クライアント同時起動で WS 同期（通常 CRUD およびアーカイブ／復元）を確認

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
- `List_IncludesArchived`（アーカイブ済みも結果に含まれる: クライアント側絞り込み前提の確認）
- `Update_ReplacesDetail`（PUT セマンティクス: detail を別の値に差し替える）
- `Update_ClearsDetailWhenNullGiven`（PUT で detail NULL を渡すと NULL になる）
- `Update_SetsArchivedAt`（archived_at に時刻を渡すと保存され、`Get` で同じ時刻が読み出せる）
- `Update_ClearsArchivedAt`（archived_at に NULL を渡すと NULL に戻る = 復元）
- `Create_ArchivedAtIsNull`（新規作成時は archived_at が NULL）
- `Label_CascadeOnWishDelete`（wish 削除で assignments が消える）
- `Label_CascadeOnWishLabelDelete`（wish_label 削除で assignments のみ消える、wish 本体は残る）
- `Create_DetailCanBeNull`

### 7.2 E2E（runn）

[tags.yaml](../api/e2e/scenarios/tags.yaml) に準じる。

**wishes.yaml**
- `create_wish_label` → `create_wish` (labelIds 指定) → `list_wishes`（labelIds が含まれている、archivedAt が null）→ `update_wish` (PUT、detail を null、archivedAt を時刻にして全置換 = アーカイブ) → `list_wishes`（archivedAt が値で返ること）→ `update_wish` (archivedAt を null = 復元) → `delete_wish`

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
- `wishesProvider` が `repo.getWishes()` の結果を返す（通常／アーカイブ済みの両方を含む）
- `activeWishesProvider` が archivedAt == null のものだけを返し、createdAt 降順
- `archivedWishesProvider` が archivedAt != null のものだけを返し、archivedAt 降順
- ラベルフィルタ指定で `activeWishesProvider` / `archivedWishesProvider` の両方が絞り込まれる
- `WishNotifier.addWish` が repo を呼び invalidate される
- `WishNotifier.archiveWish` が `archivedAt: DateTime` で repo を呼び invalidate される
- `WishNotifier.restoreWish` が `archivedAt: null` で repo を呼び invalidate される
- `WishNotifier.deleteWish` 同上

**wish_label_provider_test.dart**
- `findOrCreate`: 既存名がある場合は既存 ID を返し API を叩かない
- `findOrCreate`: 新規名は API を叩いて invalidate
- `delete` 後、`selectedWishLabelFilterProvider` がそのラベルを指していたら null に戻る（この連動が本当に必要かは 5.3 で再検討）

### 8.4 ウィジェットテスト（`app/test/presentation/pages/`）

**wish_list_page_test.dart**
- 空状態メッセージが出る
- 通常の wish 2 件＋アーカイブ済み 1 件を与えると、通常の 2 件のみが描画される
- ラベルフィルタに `null`（すべて）→ 2 件、特定ラベル → 該当 1 件、に絞られる
- FAB タップで `WishFormPage` に遷移する（`Navigator` のモックで検証）
- AppBar のアーカイブアイコンタップで `WishArchivePage` に遷移する
- カードを左スワイプ → `wishNotifier.archiveWish` が呼ばれ、SnackBar が表示される
- SnackBar の Undo タップ → `wishNotifier.restoreWish` が呼ばれる

**wish_archive_page_test.dart**
- 空状態メッセージ（「達成したやりたいことがここに残ります」）が出る
- アーカイブ済み 2 件＋通常 1 件を与えると、アーカイブ済みの 2 件のみが描画される（archivedAt 降順）
- 各カードに「達成: 〜前」の相対時刻が表示される
- FAB は配置されていない
- カードを左スワイプ → `wishNotifier.restoreWish` が呼ばれ、SnackBar が表示される
- SnackBar の Undo タップ → `wishNotifier.archiveWish` が呼ばれる
- ラベルフィルタが通常画面と同じく機能する

**wish_form_page_test.dart**
- 新規モード: タイトル空なら保存ボタンがタップされても repo が呼ばれない（バリデーション）
- タイトルに改行を含めようとしても `inputFormatters` で弾かれる
- 詳細を空で保存できる
- 編集モード: 既存値が initialValue に載っている
- ラベル Chip を選択→保存時に `labelIds` に含まれる
- **archivedAt の保持**: アーカイブ済み wish を編集モードで開き、タイトルだけ書き換えて保存すると、`updateWish` 呼び出しの `archivedAt` 引数が編集前の値（非 null）と等しい
- 通常 wish を編集モードで開き保存すると、`archivedAt` 引数が null のまま（誤ってアーカイブされない）
- **未確定ラベルがある状態で保存**: ラベル入力フィールドにテキストを入力したまま（Enter/選択で確定せず）保存ボタンをタップすると、`SnackBar` が表示され、repo の `addWish` / `updateWish` が呼ばれない

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
| 5 | 通常／アーカイブ画面のラベルフィルタ共有 | `selectedWishLabelFilterProvider` を 1 本のまま両画面で共有する | 画面遷移してもフィルタが残る挙動を「便利」と捉えるか「驚く」かは実装後にユーザ確認。分離が必要になったら `family` で分ける |
| 6 | アーカイブのアイコン | AppBar 右上 `Icons.inventory_2_outlined` | `Icons.archive_outlined` も候補。実装時に Material の現行慣例に合わせて確定 |
| 7 | Undo の有効時間 | デフォルトの SnackBar duration（4 秒）に従う | 短いと感じたら `Duration(seconds: 6)` 程度に延長 |

---

## 10. リスクと回避策

| リスク | 回避策 |
|---|---|
| WS ブロードキャスト新規追加で既存 E2E が壊れる | `hub` は LocalHub、WS 接続がなければ no-op。E2E は HTTP のみなので影響なし |
| PUT で古いクライアントが新フィールド未送信のまま PUT してフィールドを消す | 本機能は新規なので「古いクライアント」が存在しない。将来フィールドを追加する際は PATCH への切り替え or API バージョニングを別途検討 |
| PUT による Lost Update（2 人が同時に編集→後勝ちで消える） | 本フェーズでは許容（単一ユーザーのマルチデバイス想定）。楽観ロック（`If-Match` / `updated_at` チェック）は将来検討 |
| 通常編集中に他端末でアーカイブされ、保存時に archivedAt を null で上書きしてしまう | 本フェーズでは許容（同上の Lost Update と同根の問題）。フォームを開いた時点の archivedAt を送ることで、少なくとも「自分の編集で意図せず復元する」事故は減る。同種の競合は楽観ロック導入時に解決 |
| マイグレーション適用時の既存テンプレート DB (`taskmanager_template`) | `mise run db:migrate` で適用し直す。README の手順に従えば自動で取り込まれる |
| Flutter のアイコン見た目が Android/iOS/Desktop で崩れる | 実装後に各プラットフォームで 1 度起動して確認 |
| `Dismissible` のスワイプとカードタップ（編集画面遷移）が誤動作する | `Dismissible` は左右スワイプ、タップは別ジェスチャなので競合しない。`InkWell` の `onTap` を内側に置けば自然に共存する |
