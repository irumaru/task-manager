# PUT リファクタリング計画

タスク・ステータス・優先度・タグの更新エンドポイントを **PATCH（部分更新）** から **PUT（全置換）** に統一するための実装計画。

参照: [wishes-design.md §1.3.1](./wishes-design.md) — 既に wishes / wish-labels が PUT を採用済みであり、本計画はそれに合わせて他のエンティティを揃えるもの。

---

## 1. 背景と動機

### 1.1 PATCH 実装の現状の不具合

[api/internal/db/queries/tasks.sql:31-40](../api/internal/db/queries/tasks.sql#L31-L40) の `UpdateTask` は

```sql
memo = COALESCE(sqlc.narg('memo'), memo),
```

の形を採用しており、ハンドラ [tasks.go:129-132](../api/internal/handler/tasks.go#L129-L132) では `OptString.Get()` で「未指定」と `null` を区別したのちに `*string` へ畳み込んで sqlc に渡している。SQL 側ではこの両者が同一に見えるため、**spec で `string | null` を許す nullable フィールド (`memo` / `dueDate` / `priorityId`) を `null` にクリアできない**。

[tasks.go:171](../api/internal/handler/tasks.go#L171) の `if len(req.TagIds) > 0` ガードも同様で、空配列 `[]` を送ってもタグをクリアできず、さらに直後の `result.TagIds = req.TagIds` でレスポンスと DB 状態が乖離する。

### 1.2 Flutter 側の代償

PATCH の「未指定 vs null」を Dart に持ち込むため、`clearMemo` / `clearDueDate` / `clearPriority` / `clearStatus` のフラグが 4 階層に貫通している。

- [task_repository.dart:65-71](../app/lib/domain/repositories/task_repository.dart#L65-L71)
- [task_repository_impl.dart:129-145](../app/lib/data/repositories/task_repository_impl.dart#L129-L145)
- [task_provider.dart:82-103](../app/lib/presentation/providers/task_provider.dart#L82-L103)
- [task_form_page.dart:76-87](../app/lib/presentation/pages/task_form/task_form_page.dart#L76-L87)

### 1.3 UI の実利用形態

[task_form_page.dart:75-87](../app/lib/presentation/pages/task_form/task_form_page.dart#L75-L87) は編集保存時に常に全フィールドを送出している。すなわち PATCH の「部分更新」セマンティクスを実際には使っておらず、PUT 相当の挙動を PATCH の上に擬似実装している状態である。

### 1.4 採用方針

[wishes-design.md §1.3.1](./wishes-design.md) に同等の判断が既に記録されており、wishes / wish-labels は PUT で運用されている。本計画は残るすべてのドメイン (tasks / statuses / priorities / tags) を PUT に揃え、API 全体の一貫性と実装簡素化を達成する。

---

## 2. スコープ

### 2.1 対象エンティティ

| エンティティ | 現状 | 目標 |
|---|---|---|
| tasks | PATCH | **PUT** |
| statuses | PATCH | **PUT** |
| priorities | PATCH | **PUT** |
| tags | PATCH | **PUT** |
| wishes | PUT | （変更なし） |
| wish-labels | PUT | （変更なし） |

### 2.2 スコープ外

- 並び替え専用エンドポイントの新設（`PUT /statuses/reorder` 等）。本計画では既存の `updateStatus` / `updatePriority` を全置換 PUT で叩き直す方針とし、専用エンドポイントは将来の課題とする（§5.2 参照）。
- 認可・JWT・WebSocket・スキーマ変更。
- create / delete / list / get の各オペレーション。

---

## 3. 設計

### 3.1 PUT セマンティクス

各 Update リクエストはエンティティの**全フィールド**を必須とする。サーバは受け取った値で**一括上書き**する。`null` を許すフィールドは `T | null` のままとし、明示的に `null` を送ることでクリアできる。

### 3.2 spec/main.tsp の改定

#### `UpdateTaskRequest` ([spec/main.tsp:123-130](../spec/main.tsp#L123-L130))

```tsp
// PUT semantics: full replacement. All fields required.
model UpdateTaskRequest {
  title: string;
  memo: string | null;
  dueDate: utcDateTime | null;
  statusId: string;
  priorityId: string | null;
  tagIds: string[];
}
```

ルート定義:

```tsp
@put
@route("{id}")
@doc("Update a task")
update(@path id: string, @body body: UpdateTaskRequest): Task | ApiError;
```

#### `UpdateStatusRequest` / `UpdatePriorityRequest`

```tsp
model UpdateStatusRequest {
  name: string;
  displayOrder: int32;
}
```

`@patch` → `@put` に変更。priorities も同様。

#### `UpdateTagRequest`

```tsp
model UpdateTagRequest {
  name: string;
}
```

`@patch` → `@put`。

### 3.3 SQL クエリの改定

すべての `COALESCE(sqlc.narg('xxx'), xxx)` を消し、プレーンな `$n` バインドにする。

#### `api/internal/db/queries/tasks.sql`

```sql
-- name: UpdateTask :one
UPDATE tasks SET
    title       = $3,
    memo        = $4,
    due_date    = $5,
    status_id   = $6,
    priority_id = $7,
    updated_at  = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;
```

#### `statuses.sql` / `priorities.sql`

```sql
UPDATE statuses SET
    name          = $3,
    display_order = $4,
    updated_at    = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;
```

#### `tags.sql`

```sql
UPDATE tags SET
    name       = $3,
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;
```

### 3.4 Go ハンドラの改定

`OptString.Get()` の dance を撤去し、必須フィールドはそのまま、nullable のみ pgtype/null 変換する。

#### `api/internal/handler/tasks.go` `TaskOpsUpdate`

要点:
- `req.Title` は必須（直接渡し）
- `req.Memo` / `req.DueDate` / `req.PriorityId` は `T | null`（spec 上 nullable）
- `req.TagIds` は必須（`if len > 0` ガード撤去）
- タグ更新は `SetTaskTags` で全削除 → `req.TagIds` を全 Insert（既存処理を `len > 0` ガード無しで実行）
- レスポンスの `result.TagIds = req.TagIds` を維持（PUT で同期されるため正しい）

#### `statuses.go` / `priorities.go` / `tags.go`

`var name *string; if v, ok := req.Name.Get(); ok { name = &v }` の塊を削除し、`req.Name` を直接 sqlc 引数に渡す。

### 3.5 Flutter API クライアント

[app/lib/data/api/api_client.dart](../app/lib/data/api/api_client.dart) の以下を `_dio.patch(...)` から `_dio.put(...)` へ:

- `updateTask` ([:88-90](../app/lib/data/api/api_client.dart#L88-L90))
- `updatePriority` ([:121-123](../app/lib/data/api/api_client.dart#L121-L123))
- `updateStatus` ([:154-156](../app/lib/data/api/api_client.dart#L154-L156))
- `updateTag` ([:187-189](../app/lib/data/api/api_client.dart#L187-L189))

### 3.6 Flutter ドメイン層 / データ層

#### `task_repository.dart` / `task_repository_impl.dart`

`updateTask` の引数を全フィールド必須化し、`clearXxx` フラグを全廃する。

```dart
Future<Task> updateTask({
  required String id,
  required String title,
  required String? memo,
  required DateTime? dueDate,
  required String statusId,
  required String? priorityId,
  required List<String> tagIds,
});
```

実装側のリクエスト Map 構築は条件分岐なしの直線になる:

```dart
final json = await _api.updateTask(id, {
  'title': title,
  'memo': memo,
  'dueDate': dueDate?.toUtc().toIso8601String(),
  'statusId': statusId,
  'priorityId': priorityId,
  'tagIds': tagIds,
});
```

#### status / priority / tag リポジトリ

`updateStatus({required String id, required String name, required int displayOrder})` のように全必須化。`tag` は `name` のみで既に必須。

### 3.7 Flutter プレゼンテーション層

#### `task_provider.dart`

`TaskNotifier.updateTask` から `clearXxx` を削除し、全必須引数に変更。

#### `task_form_page.dart`

[:75-87](../app/lib/presentation/pages/task_form/task_form_page.dart#L75-L87) の `clearMemo: memo.isEmpty,` 等を撤去し、純粋に値（または `null`）を渡す形にする。

```dart
await notifier.updateTask(
  id: widget.task!.id,
  title: _titleController.text.trim(),
  memo: memo.isEmpty ? null : memo,
  dueDate: _dueDate,
  priorityId: _priorityId,
  statusId: _statusId!,
  tagIds: tagIds,
);
```

#### `Task.copyWith` の `clearXxx` 引数

[task.dart:40-65](../app/lib/domain/models/task.dart#L40-L65) の `clearMemo` / `clearDueDate` / `clearPriorityId` / `clearStatusId` / `clearPriority` / `clearStatus` は **PUT リファクタの直接スコープ外**だが、依存している箇所（[task_provider.dart:44-46](../app/lib/presentation/providers/task_provider.dart#L44-L46)）が `clearXxx` を引数経由で渡している。`Task.copyWith` は domain モデルのユーティリティなのでそのまま残してもよいが、タスク完了後にスコープ拡張として利用箇所の整理を検討する（§5.3）。

### 3.8 並び替え (`reorderStatuses` / `reorderPriorities`) の対応

[status_repository_impl.dart:44-48](../app/lib/data/repositories/status_repository_impl.dart#L44-L48) は

```dart
await _api.updateStatus(orderedIds[i], {'displayOrder': i});
```

と `displayOrder` のみの部分更新を行っている。PUT 化後は `name` も必須となる。

**方針**: Notifier 層で対応する。`StatusNotifier` ([status_provider.dart](../app/lib/presentation/providers/status_provider.dart)) は `AsyncNotifier<List<Status>>` で **既に名前を含む全 Status をキャッシュ**している。`reorderStatuses` のシグネチャを `List<String> orderedIds` から `List<Status> orderedItems`（または `Map<String, String> idToName` + ids）に変更し、リポジトリ側で全フィールド付き PUT を発行する。

```dart
// repository
Future<void> reorderStatuses(List<Status> ordered) async {
  for (var i = 0; i < ordered.length; i++) {
    await _api.updateStatus(ordered[i].id, {
      'name': ordered[i].name,
      'displayOrder': i,
    });
  }
}

// notifier
Future<void> reorder(List<String> orderedIds) async {
  final current = state.value ?? [];
  final byId = {for (final s in current) s.id: s};
  final ordered = orderedIds.map((id) => byId[id]!).toList();
  await ref.read(statusRepositoryProvider).reorderStatuses(ordered);
  ref.invalidateSelf();
}
```

priorities も同形。トランザクション境界は変わらず、N 回の HTTP PUT を順次発行する（既存挙動と同等）。

---

## 4. テスト

### 4.1 e2e (`runn`)

以下のシナリオを `patch:` から `put:` に変更し、必須フィールドを補う:

- [api/e2e/scenarios/tasks.yaml:66-69](../api/e2e/scenarios/tasks.yaml#L66-L69)
- [api/e2e/scenarios/statuses.yaml:28-31](../api/e2e/scenarios/statuses.yaml#L28-L31)
- [api/e2e/scenarios/priorities.yaml:28-31](../api/e2e/scenarios/priorities.yaml#L28-L31)
- [api/e2e/scenarios/tags.yaml:27-30](../api/e2e/scenarios/tags.yaml#L27-L30)

加えて以下のリグレッション防止ケースを追加（最低限 tasks のみで可）:

1. `memo` を `null` 指定で送って **DB 上 `memo` が NULL になる** ことを GET で検証。
2. `tagIds: []` で送って **タスクのタグ全削除** が反映されることを検証。
3. `priorityId` を `null` で送ってクリアできることを検証。

### 4.2 リポジトリ統合テスト

[api/internal/repository-test/tasks_test.go:125-153](../api/internal/repository-test/tasks_test.go#L125-L153) を新シグネチャに合わせ、上記 nullable クリアケースを追加。

### 4.3 Flutter

UI 層のユニットテストは現状なし。`task_form_page` のゴールデンパス（編集 → 保存 → 一覧反映）を手動で確認する。

---

## 5. リスクと将来の課題

### 5.1 互換性

クライアントとサーバを別タイミングでリリースするとリクエストが失敗する。**同一 PR / 同一リリースで一気に切り替える**。サーバが PATCH ルートを失うため、旧クライアントは 405 を受ける。Flutter のフォース更新ポリシーは現状未配備のため、リリース後は古いクライアントが一時的に動かない期間が発生しうる点を許容する。

### 5.2 並び替えの N+1 PUT

§3.8 で `name` を含めて PUT を N 回発行することで、ペイロードがわずかに増える。性能上の懸念は無いが、将来 `PUT /statuses/reorder` のような専用エンドポイントを切れば 1 リクエストで済む。本計画ではスコープ外。

### 5.3 `Task.copyWith` の `clearXxx` 引数

PUT 化後はリポジトリ層で不要となるが、`copyWith` は別の Dart 慣用句として残ることもある。本計画では削除しないが、利用箇所が `clearXxx` 不要に縮退するため、後続コミットで段階的に整理する余地がある。

---

## 6. 実装手順

各ステップで `mise run gen` を流し、生成物の差分も同コミットに含める。

1. **spec を改定** ([spec/main.tsp](../spec/main.tsp)):
   - tasks / statuses / priorities / tags の `Update*Request` を全必須化、`@patch` → `@put`。
2. **`mise run gen:tsp` → `mise run gen:go:ogen`** を実行し、`api/internal/api/oas_*_gen.go` を再生成。
3. **SQL を改定** (`api/internal/db/queries/{tasks,statuses,priorities,tags}.sql`):
   - `UPDATE` 文の `COALESCE(sqlc.narg(...), col)` を `$n` に置換。
4. **`mise run gen:go:sqlc`** で `api/internal/repository/*.sql.go` を再生成。
5. **Go ハンドラを書き換え** (`api/internal/handler/{tasks,statuses,priorities,tags}.go`):
   - `OptString.Get()` の dance を撤去。
   - tasks の tag 更新の `len > 0` ガードを撤去。
6. **リポジトリテスト改定** (`api/internal/repository-test/tasks_test.go` 他)、新シグネチャに追従、nullable クリアケース追加。
7. **e2e シナリオ改定** (`api/e2e/scenarios/*.yaml`): `patch` → `put`、必須フィールド付与、クリアケース追加。
8. **`cd api && go build ./... && go test ./internal/repository-test/... && go test ./e2e/...`** が緑になることを確認。
9. **Flutter API クライアント** ([api_client.dart](../app/lib/data/api/api_client.dart)) を `_dio.put` に切替。
10. **Flutter ドメイン / データ / プロバイダ** から `clearXxx` を全廃し、必須化。
11. **`task_form_page.dart`** の保存呼び出しを単純化。
12. **並び替えロジック** ([status_repository_impl.dart](../app/lib/data/repositories/status_repository_impl.dart) / [priority_repository_impl.dart](../app/lib/data/repositories/priority_repository_impl.dart) / 対応 provider) を §3.8 のとおり改定。
13. **`flutter analyze`** が緑になることを確認、ローカルで編集・並び替え・nullable クリアを手動確認。
14. **PR 作成**。タイトル例: `refactor: switch tasks/statuses/priorities/tags update from PATCH to PUT`。

---

## 7. 完了条件

- すべての更新リクエストが PUT で発行され、サーバが PATCH ルートを返さないこと。
- タスクの `memo` / `dueDate` / `priorityId` / `tagIds` が PUT で `null` ないし空配列にクリアできること（e2e で実証）。
- Flutter コードベースから `clearMemo` / `clearDueDate` / `clearPriority` / `clearStatus` の引数定義と引き回しが消えていること（`Task.copyWith` の `clearXxx` を除く。§5.3）。
- `mise run gen` を再実行しても差分が出ないこと（CI `test-generated.yml` がグリーン）。
