---
title: やりたいこと アーカイブ機能 設計書
---

# やりたいこと アーカイブ機能 設計書

関連: [wishes-design.md](./wishes-design.md) / [wishes-specification.md](./wishes-specification.md)

本書は、既存の「やりたいこと」機能にアーカイブ機能を追加するための設計を定める。要件は以下の 3 点。

1. 編集画面にアーカイブボタンを追加する
2. アーカイブされたやりたいことは、default で一覧に表示しない
3. アーカイブされたやりたいことを表示するボタンを一覧につける

---

## 1. 設計判断と理由

実装前に決めたこと。要件に明記されていない部分の判断。

### 1.1 「アーカイブ」を boolean ではなく `archived_at TIMESTAMPTZ NULL` で表す

**採用理由**:
- いつアーカイブしたかが必要になる場面（並び順、UI 上の表示）に対応できる
- 既存の `created_at` / `updated_at` と同じ TIMESTAMPTZ で揃う
- `WHERE archived_at IS NULL` / `IS NOT NULL` で絞り込めて、index 化も容易

**トレードオフ**: BOOLEAN より 1 カラム分情報量が増える。だが「いつアーカイブされたか」は将来 UI で十分価値があると判断（アーカイブ一覧を「アーカイブした日時の降順」で並べるのは自然）。

### 1.2 アーカイブ操作は専用エンドポイント `POST /wishes/{id}/archive` / `unarchive`

既存の `PUT /wishes/{id}` は title/detail/labelIds の **全置換** セマンティクスである（[wishes-design.md §1.3.1](./wishes-design.md)）。ここに `archived` フィールドを足すと:

- PUT は「リソース全体を送る」契約なので、クライアントは毎回 `archived: false` を明示送信する必要が生じる
- 「アーカイブする」だけのリクエストでも title/detail/labelIds の現在値を全部送らなければならず、ロストアップデートのリスクが増える

**採用方針**: アーカイブはステートトグルの専用 API として独立させる。

```
POST   /wishes/{id}/archive       → archived_at = NOW()
POST   /wishes/{id}/unarchive     → archived_at = NULL
```

レスポンスは更新後の `Wish` を返す（クライアントの楽観更新に使えるため）。

### 1.3 一覧 API は `?includeArchived=true` でアーカイブ済みも含めて返す

別エンドポイント（`/wishes/archived`）にする案もあるが、

- フィルタ（ラベル）と組み合わせると、エンドポイントを 2 系統で重複定義することになる
- クライアント側のコードも 2 系統になり、provider が増える

**採用方針**: 単一エンドポイントにクエリパラメータ。

```
GET /wishes                        → archived_at IS NULL のみ
GET /wishes?includeArchived=true   → 全件（アーカイブ済みも含む）
```

「アーカイブのみを見る」モードは要件に無いので追加しない（YAGNI）。**未アーカイブのみ** か **両方（混在表示）** かの 2 モードだけ。混在表示時にアーカイブ済みは UI 上区別できるよう見た目を変える（5.4 参照）。

### 1.4 アーカイブ済みも編集画面で開ける

要件 3 で「アーカイブされたやりたいことを表示する」ことになっており、表示後に「アーカイブ解除」が必要になる。専用画面を用意するより、既存編集画面の「アーカイブ」ボタンを「アーカイブ解除」に切り替える方が実装も UI も単純。

**採用方針**:
- 編集画面でアーカイブ済みを開いたら、ボタン表記を「アーカイブ」→「アーカイブ解除」に切り替える
- アーカイブ済みでもタイトル / 詳細 / ラベルの編集は可能とする（凍結はしない）

### 1.5 削除ボタンは残す

既存 [wish_form_page.dart:140-144](../app/lib/presentation/pages/wish_form/wish_form_page.dart#L140-L144) の削除ボタンはそのまま。アーカイブ（非破壊）と削除（完全削除）は別操作として両方残す。

### 1.6 WebSocket イベントは既存の `wish.changed` を流用

archive / unarchive も「wish の状態が変わった」だけなので、既存の集約方針（[wishes-design.md §4.4](./wishes-design.md)）通り `wish.changed` 1 種でよい。新規イベント種別は追加しない。

---

## 2. 追加・変更するファイル一覧

### 2.1 既存ファイルの改変

| パス | 変更内容 |
|---|---|
| [schema.sql](../../schema.sql) | `wishes` テーブルに `archived_at TIMESTAMPTZ NULL` 追加 |
| [spec/main.tsp](../../spec/main.tsp) | `Wish.archivedAt` フィールド追加、`list` に `includeArchived` クエリ、`archive` / `unarchive` オペレーション追加 |
| [api/internal/db/queries/wishes.sql](../../api/internal/db/queries/wishes.sql) | `ListWishes` / `ListWishesIncludingArchived` 切替、`ArchiveWish` / `UnarchiveWish` 追加 |
| [api/internal/handler/wishes.go](../../api/internal/handler/wishes.go) | `WishOpsArchive` / `WishOpsUnarchive` ハンドラ実装、`WishOpsList` に `includeArchived` 分岐 |
| [api/internal/handler/convert.go](../../api/internal/handler/convert.go) | `toAPIWish` に `archivedAt` を渡すよう拡張 |
| [api/internal/repository-test/wishes_test.go](../../api/internal/repository-test/wishes_test.go) | アーカイブ系ケース追加（7 章） |
| [api/e2e/scenarios/wishes.yaml](../../api/e2e/scenarios/wishes.yaml) | archive → list (default) → list (includeArchived) → unarchive のシナリオ追加 |
| [app/lib/domain/models/wish.dart](../../app/lib/domain/models/wish.dart) | `archivedAt: DateTime?` フィールド追加 |
| [app/lib/domain/repositories/wish_repository.dart](../../app/lib/domain/repositories/wish_repository.dart) | `getWishes({bool includeArchived})`, `archiveWish`, `unarchiveWish` 追加 |
| [app/lib/data/repositories/wish_repository_impl.dart](../../app/lib/data/repositories/wish_repository_impl.dart) | 上記の実装 |
| [app/lib/data/api/api_client.dart](../../app/lib/data/api/api_client.dart) | `archiveWish` / `unarchiveWish` メソッド、`getWishes` に `includeArchived` クエリ追加 |
| [app/lib/presentation/providers/wish_provider.dart](../../app/lib/presentation/providers/wish_provider.dart) | `showArchivedProvider` 追加、`wishesProvider` を `family` 化または `showArchived` を watch、`archive` / `unarchive` メソッド追加 |
| [app/lib/presentation/pages/wish_list/wish_list_page.dart](../../app/lib/presentation/pages/wish_list/wish_list_page.dart) | AppBar アクションに「アーカイブを表示/隠す」トグルボタン追加 |
| [app/lib/presentation/pages/wish_list/widgets/wish_card.dart](../../app/lib/presentation/pages/wish_list/widgets/wish_card.dart) | アーカイブ済みは半透明＋アイコンで区別 |
| [app/lib/presentation/pages/wish_form/wish_form_page.dart](../../app/lib/presentation/pages/wish_form/wish_form_page.dart) | AppBar の actions にアーカイブ／アーカイブ解除ボタン追加 |
| [app/test/presentation/providers/wish_provider_test.dart](../../app/test/presentation/providers/wish_provider_test.dart) | `showArchived` トグルでクエリが切り替わるテスト追加 |
| [app/test/presentation/pages/wish_form/wish_form_page_test.dart](../../app/test/presentation/pages/wish_form/wish_form_page_test.dart) | アーカイブボタンの表示／タップ挙動テスト |

### 2.2 自動生成（手で編集しない）

| 生成元 | 出力 |
|---|---|
| `spec/main.tsp` | `spec/tsp-output/openapi.yaml`, `api/internal/api/oas_*_gen.go` |
| `schema.sql` | `migrator/migrations/*_add_wishes_archived_at.sql` |
| `api/internal/db/queries/wishes.sql` | `api/internal/repository/wishes.sql.go` + `models.go` |

---

## 3. DB 設計

[schema.sql](../../schema.sql) の `wishes` を以下に変更する。

```sql
CREATE TABLE wishes (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT        NOT NULL,
    detail      TEXT,
    archived_at TIMESTAMPTZ,                                  -- 追加
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL
);
```

**index は当面追加しない**。1 ユーザーあたりのやりたいこと件数は数十〜数百のオーダーを想定しており、`WHERE user_id = $1 AND archived_at IS NULL` のフィルタで十分高速に応答できる。データ量が増え、`EXPLAIN ANALYZE` で問題が見えた段階で `(user_id, archived_at)` 複合 index を検討する。

マイグレーションは `mise run db:migrations:create` で Atlas に diff を取らせる（既存 `wishes` テーブルへのカラム追加なので `ALTER TABLE` が出力される）。

---

## 4. API 層

### 4.1 TypeSpec 変更

```typespec
model Wish {
  id: string;
  title: string;
  detail: string | null;
  labelIds: string[];
  archivedAt: utcDateTime | null;     // 追加
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

@route("/wishes")
@tag("Wishes")
@useAuth(BearerAuth)
interface WishOps {
  @get list(@query includeArchived?: boolean): WishList | ApiError;   // 変更
  @post create(@body body: CreateWishRequest): Wish | ApiError;
  @get  @route("{id}") get(@path id: string): Wish | ApiError;
  @put  @route("{id}") update(@path id: string, @body body: UpdateWishRequest): Wish | ApiError;
  @delete @route("{id}") delete(@path id: string): void | ApiError;

  // 追加
  @post @route("{id}/archive")   archive(@path id: string):   Wish | ApiError;
  @post @route("{id}/unarchive") unarchive(@path id: string): Wish | ApiError;
}
```

`includeArchived` を省略 / `false` で「未アーカイブのみ」、`true` で「全件」。

### 4.2 sqlc クエリ

[api/internal/db/queries/wishes.sql](../../api/internal/db/queries/wishes.sql) を変更。

```sql
-- name: ListWishes :many
-- 未アーカイブのみ
SELECT
    w.*,
    COALESCE(
        ARRAY_AGG(a.wish_label_id) FILTER (WHERE a.wish_label_id IS NOT NULL),
        '{}'
    )::uuid[] AS label_ids
FROM wishes w
LEFT JOIN wish_label_assignments a ON a.wish_id = w.id
WHERE w.user_id = $1 AND w.archived_at IS NULL
GROUP BY w.id
ORDER BY w.created_at DESC;

-- name: ListWishesIncludingArchived :many
-- アーカイブ済みも含む全件。アーカイブ済みは末尾、未アーカイブは created_at DESC で並べる。
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
ORDER BY (w.archived_at IS NOT NULL), w.created_at DESC;

-- name: ArchiveWish :one
UPDATE wishes
SET archived_at = NOW(), updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: UnarchiveWish :one
UPDATE wishes
SET archived_at = NULL, updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;
```

`ListWishes` と `ListWishesIncludingArchived` は別クエリにする（sqlc では条件付き WHERE をきれいに書けないため）。ハンドラ側で分岐する。

`Get` クエリ（既存）はアーカイブの状態に関わらず単一行を返すので変更不要。

### 4.3 Handler 実装

#### `WishOpsList` の変更

```go
func (h *Handler) WishOpsList(ctx context.Context, params api.WishOpsListParams) (*api.WishList, error) {
    userID := /* ctx から取得 */
    if params.IncludeArchived.Value {
        rows, err := h.q.ListWishesIncludingArchived(ctx, userID)
        // ...
    } else {
        rows, err := h.q.ListWishes(ctx, userID)
        // ...
    }
    // toAPIWish で変換
}
```

#### `WishOpsArchive` / `WishOpsUnarchive`

```go
func (h *Handler) WishOpsArchive(ctx context.Context, params api.WishOpsArchiveParams) (*api.Wish, error) {
    userID := /* ctx から取得 */
    id, err := uuid.Parse(params.ID)
    if err != nil { return nil, statusError{400, "invalid id"} }

    row, err := h.q.ArchiveWish(ctx, repository.ArchiveWishParams{ID: id, UserID: userID})
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) { return nil, statusError{404, "wish not found"} }
        return nil, err
    }

    // 既存の Get と同様に label_ids を取得して toAPIWish へ
    labelIDs, err := h.q.ListWishLabelIdsByWish(ctx, id)  // 既存になければ Get を流用
    // ...

    h.hub.Broadcast(userID, websocket.Event{Type: "wish.changed", Payload: struct{}{}})
    return toAPIWish(row, labelIDs), nil
}
```

`Unarchive` も同形で `archived_at = NULL` に戻す。

**バリデーション**:
- 既にアーカイブ済みの wish に対する archive / 既に未アーカイブの wish に対する unarchive は **冪等に成功扱い** とする（200 OK で現状を返す）。クライアントが状態を厳密に把握していなくても呼べる。実装上、`UPDATE` は条件に合致した行を返すだけなので追加分岐は不要。

#### `convert.go` の `toAPIWish` 拡張

`Wish.ArchivedAt` を `repository.Wish.ArchivedAt`（`pgtype.Timestamptz`）から OAS の `OptDateTime` に変換する。既存の `nilStringFromPtr` 同様の `optDateTimeFromPgtype` ヘルパを足す（無ければ）。

### 4.4 WebSocket

archive / unarchive のハンドラ末尾で `h.hub.Broadcast(userID, websocket.Event{Type: "wish.changed"})` を呼ぶ。クライアント側分岐の追加は不要（既存 `wish.changed` で `wishesProvider` を invalidate しているため）。

---

## 5. Flutter クライアント

### 5.1 domain 層

#### `Wish` モデルに `archivedAt` 追加

```dart
class Wish {
  final String id;
  final String title;
  final String? detail;
  final List<String> labelIds;
  final DateTime? archivedAt;          // 追加
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;
  // ...
}
```

#### `WishRepository` 拡張

```dart
abstract class WishRepository {
  Future<List<Wish>> getWishes({bool includeArchived = false});  // 変更
  Future<Wish> addWish({...});
  Future<Wish> updateWish({...});
  Future<void> deleteWish(String id);
  Future<Wish> archiveWish(String id);                            // 追加
  Future<Wish> unarchiveWish(String id);                          // 追加
}
```

### 5.2 data 層

`api_client.dart` に 2 メソッド追加（`POST /wishes/{id}/archive` / `unarchive`）。`getWishes` に `includeArchived` クエリパラメータを追加。

`wish_repository_impl.dart` で同等のメソッドを実装。

### 5.3 presentation 層

#### `wish_provider.dart` の変更

```dart
// アーカイブ済みも一覧に含めて表示するか
final showArchivedProvider = StateProvider<bool>((ref) => false);

// wishesProvider は showArchived を watch して切り替える
final wishesProvider = FutureProvider<List<Wish>>((ref) async {
  final repo = ref.watch(wishRepositoryProvider);
  final showArchived = ref.watch(showArchivedProvider);
  return repo.getWishes(includeArchived: showArchived);
});

// filteredWishesProvider は既存のラベルフィルタ適用のみ（変更なし）。
// アーカイブのフィルタはサーバ側で済むのでクライアントでは何もしない。

class WishNotifier extends AsyncNotifier<void> {
  // ...
  Future<void> archiveWish(String id) async {
    await ref.read(wishRepositoryProvider).archiveWish(id);
    ref.invalidate(wishesProvider);
  }
  Future<void> unarchiveWish(String id) async {
    await ref.read(wishRepositoryProvider).unarchiveWish(id);
    ref.invalidate(wishesProvider);
  }
}
```

`showArchivedProvider` の値が変わると `wishesProvider` が自動で再フェッチされる（依存追跡で `invalidate` 不要）。

#### `wish_list_page.dart` の変更

AppBar の `actions` に切替ボタンを追加。

```dart
appBar: AppBar(
  title: const Text('やりたいこと'),
  actions: [
    Consumer(builder: (context, ref, _) {
      final showArchived = ref.watch(showArchivedProvider);
      return IconButton(
        icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
        tooltip: showArchived ? 'アーカイブを隠す' : 'アーカイブを表示',
        onPressed: () => ref.read(showArchivedProvider.notifier).state = !showArchived,
      );
    }),
  ],
),
```

#### `wish_card.dart` の変更

アーカイブ済みは視覚的に区別する。

```dart
final isArchived = wish.isArchived;
return Opacity(
  opacity: isArchived ? 0.55 : 1.0,
  child: Card(
    // 既存 ListTile に leading として archive アイコンを付ける（アーカイブ済みのみ）
    child: ListTile(
      leading: isArchived ? const Icon(Icons.archive_outlined, size: 20) : null,
      // ...
    ),
  ),
);
```

#### `wish_form_page.dart` の変更

AppBar の `actions` にアーカイブ／アーカイブ解除ボタンを追加（編集モード時のみ。新規追加時は出さない）。

```dart
actions: [
  if (_isEditing) ...[
    IconButton(
      icon: Icon(widget.wish!.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
      tooltip: widget.wish!.isArchived ? 'アーカイブ解除' : 'アーカイブ',
      onPressed: _toggleArchive,
    ),
    IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: _delete,
      color: Colors.red,
    ),
  ],
],
```

```dart
Future<void> _toggleArchive() async {
  final notifier = ref.read(wishNotifierProvider.notifier);
  if (widget.wish!.isArchived) {
    await notifier.unarchiveWish(widget.wish!.id);
  } else {
    await notifier.archiveWish(widget.wish!.id);
  }
  if (mounted) Navigator.pop(context);
}
```

**未保存の編集との衝突**: アーカイブボタンを押した時点では未保存のフォーム入力は破棄される（Navigator.pop で抜けるため）。確認ダイアログを出すかは UX 判断。本フェーズではシンプルさを優先して確認なしとする（誤操作復旧は「アーカイブ解除」で可能なため致命的ではない）。

### 5.4 アーカイブ済みのソート位置

API の `ListWishesIncludingArchived` で `ORDER BY (archived_at IS NOT NULL), created_at DESC` としており、未アーカイブが上、アーカイブ済みが下に並ぶ。クライアント側でのソート操作は不要。

---

## 6. 実装順序

### ステップ 1 — スキーマと生成物

1. `schema.sql` の `wishes` に `archived_at` 追加
2. `spec/main.tsp` の `Wish` / `WishOps` を更新
3. `api/internal/db/queries/wishes.sql` を更新（4 クエリ追加・変更）
4. `mise run gen` 実行
5. `mise run db:migrations:create` 実行
6. `cd api && go build ./...`

### ステップ 2 — API ハンドラ

1. `WishOpsList` の `includeArchived` 分岐
2. `WishOpsArchive` / `WishOpsUnarchive` 実装
3. `convert.go` の `toAPIWish` を `archivedAt` 対応に
4. `repository-test/wishes_test.go` にケース追加
5. `cd api && go test ./...`

### ステップ 3 — E2E

`e2e/scenarios/wishes.yaml` にアーカイブ系ステップ追加。

### ステップ 4 — Flutter

1. `Wish` モデルに `archivedAt` 追加
2. `WishRepository` IF / impl 拡張、`api_client.dart` 更新
3. `wish_provider.dart` に `showArchivedProvider`, `archiveWish`, `unarchiveWish`
4. `wish_list_page.dart` の AppBar アクション
5. `wish_card.dart` のアーカイブ表示
6. `wish_form_page.dart` のアーカイブボタン

### ステップ 5 — Flutter テスト

7 章を参照。

### ステップ 6 — 動作確認

`docker compose up -d` → Flutter 起動 → 追加 → アーカイブ → 一覧から消える → トグル ON → 再表示 → アーカイブ解除 → 通常表示に戻る、を確認。

---

## 7. テスト計画

### 7.1 repository-test 追加ケース

**wishes_test.go**
- `Archive_SetsArchivedAt`: archive すると `archived_at` が non-null になる
- `Unarchive_ClearsArchivedAt`: unarchive すると `archived_at` が NULL になる
- `Archive_IsIdempotent`: 既にアーカイブ済みの wish を archive しても成功して同じ状態
- `ListWishes_ExcludesArchived`: archive した wish が `ListWishes` に出てこない
- `ListWishesIncludingArchived_IncludesAll`: archive した wish も含めて返ってくる
- `ListWishesIncludingArchived_ArchivedAtBottom`: 並び順がアーカイブ済み末尾、未アーカイブは created_at DESC

### 7.2 E2E（runn）

`wishes.yaml` の既存シナリオに以下を追記:

1. `archive_wish` (POST `/wishes/{id}/archive`)
2. `list_default` → archive 済みが含まれていない
3. `list_with_archived` (`?includeArchived=true`) → 含まれる
4. `unarchive_wish` (POST `/wishes/{id}/unarchive`)
5. `list_default` → 再び含まれる

### 7.3 Flutter テスト

**wish_provider_test.dart**
- `showArchivedProvider = false` で repo の `getWishes(includeArchived: false)` が呼ばれる
- `showArchivedProvider = true` に切り替えると `getWishes(includeArchived: true)` が呼ばれる
- `archiveWish` を呼ぶと repo が呼ばれ `wishesProvider` が invalidate

**wish_form_page_test.dart**
- 新規追加モード（wish == null）ではアーカイブボタンが出ない
- 編集モードで未アーカイブの場合 `Icons.archive_outlined` が出る
- 編集モードでアーカイブ済みの場合 `Icons.unarchive_outlined` が出る
- アーカイブボタンタップで `archiveWish` が呼ばれ Navigator.pop される
- アーカイブ解除ボタンタップで `unarchiveWish` が呼ばれる

**wish_list_page_test.dart**
- AppBar のトグルボタンタップで `showArchivedProvider` が切り替わる
- アーカイブ済み wish には `Opacity(opacity < 1.0)` と archive アイコンが描画される

---

## 8. オープンな決定事項

| # | 項目 | 現在の方針 |
|---|---|---|
| 1 | アーカイブ時の確認ダイアログ | 出さない（unarchive で復旧可能なため） |
| 2 | アーカイブ済み wish のラベル編集可否 | 可（凍結しない） |
| 3 | アーカイブ済みのバルク削除機能 | スコープ外（要件なし） |

---

## 9. リスクと回避策

| リスク | 回避策 |
|---|---|
| 既存 wish レコードへの `ALTER TABLE ADD COLUMN archived_at` がプロダクション DB で長時間ロック | 当該カラムは NULL 許容なので PostgreSQL では即時完了する（PG 11 以降）。問題なし |
| 既存クライアント（古いバージョン）は `archivedAt` フィールドを知らない | 既存クライアントは無視するだけで動作不能にはならない。サーバは後方互換 |
| アーカイブされた wish が WS の `wish.changed` で送られると、ラベルフィルタ表示中の他クライアントで意図せず非表示になるなどの挙動 | invalidate して再フェッチするだけなので、サーバの最新状態（未アーカイブのみ）が反映されて整合する |
