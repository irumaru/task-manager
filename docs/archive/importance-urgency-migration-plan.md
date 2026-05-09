# 優先度 → 重要度・緊急度 移行 実装計画

## 1. 概要・方針

タスクの「優先度（priority）」を廃止し、独立した2軸「**重要度（importance）**」と「**緊急度（urgency）**」に置き換える。これによりアイゼンハワー・マトリクス的な分類が可能になる。

### 1.1 採用方針

- **データ構造**: `tasks` テーブルに直接 `importance INT NOT NULL DEFAULT 1` / `urgency INT NOT NULL DEFAULT 1` カラムを追加する。値は **1〜3 の固定スケール**（1=低 / 2=中 / 3=高、**数値が大きい方が優先・重要**）。
- **既存データ**: `priorities` テーブルおよび関連 API・UI・ユーザー定義ラベル機能は **完全に削除する**。マイグレーションでデータの引き継ぎは行わない。
- **API**: `/priorities` CRUD エンドポイントは削除。重要度・緊急度はマスター管理が不要なので専用エンドポイントは作らず、`Task` モデルの `importance` / `urgency` フィールドだけで完結する。
- **バリデーション**: API ハンドラ層で 1〜3 の範囲チェックを行う。

### 1.2 スコープ外

- 重要度・緊急度を組み合わせた 4 象限マトリクスビュー UI（既存の単一ドロップダウン UI を 2 つ並べる形に留める）
- 重要度・緊急度を活用した複合ソート（「重要かつ緊急を最上位」など）。単軸でのソート/フィルタは UI 拡張時に検討
- 既存の優先度データの自動移行ロジック

---

## 2. 影響範囲（既存実装からの変更点）

### 2.1 SQL / マイグレーション

- [schema.sql](../../schema.sql):
  - `priorities` テーブル削除
  - `tasks.priority_id` 削除
  - `tasks.importance INT NOT NULL DEFAULT 1` 追加
  - `tasks.urgency INT NOT NULL DEFAULT 1` 追加
  - 1〜3 の範囲を保証する CHECK 制約 `CHECK (importance BETWEEN 1 AND 3)` / `CHECK (urgency BETWEEN 1 AND 3)` を付ける
- [migrator/migrations/](../../migrator/migrations/): `mise run db:migrations:create` で新規マイグレーション 1 ファイル生成

### 2.2 sqlc クエリ（手書き）

- [api/internal/db/queries/priorities.sql](../../api/internal/db/queries/priorities.sql): **削除**
- [api/internal/db/queries/tasks.sql](../../api/internal/db/queries/tasks.sql): `INSERT` / `UPDATE` の `priority_id` を `importance` / `urgency` に置換

### 2.3 TypeSpec 仕様

- [spec/main.tsp](../../spec/main.tsp):
  - `Priority` / `PriorityList` / `CreatePriorityRequest` / `UpdatePriorityRequest` モデルと `PriorityOps` インターフェイス（210-245行目）を **削除**
  - `Task` モデルの `priorityId: string | null` を `importance: int32` / `urgency: int32` に置換
  - `CreateTaskRequest` の `priorityId?: string` を `importance?: int32`（省略時はサーバー側でデフォルト 1）/ `urgency?: int32` に置換
  - `UpdateTaskRequest` の `priorityId: string | null` を `importance: int32` / `urgency: int32` に置換（PUT セマンティクスのため必須）

### 2.4 Go ハンドラ（手書き）

- [api/internal/handler/priorities.go](../../api/internal/handler/priorities.go): **削除**
- [api/internal/handler/tasks.go](../../api/internal/handler/tasks.go):
  - `priorityId` 関連の UUID パース処理を削除
  - `importance` / `urgency` の値検証（1〜3）を追加。範囲外なら `errBadRequest` を返す
  - Create 時に省略されたら 1 をデフォルトとして使用
- [api/internal/handler/convert.go](../../api/internal/handler/convert.go):
  - `toAPIPriority` 関数を **削除**
  - `toAPITaskFromRow` / `toAPITaskFromGetRow` / `toAPITaskFromTask` の `PriorityId: nilStringFromNullUUID(...)` を `Importance: row.Importance` / `Urgency: row.Urgency` に置換

### 2.5 リポジトリテスト（手書き）

- [api/internal/repository-test/priorities_test.go](../../api/internal/repository-test/priorities_test.go): **削除**
- [api/internal/repository-test/tasks_test.go](../../api/internal/repository-test/tasks_test.go): `PriorityID` 関連を `Importance` / `Urgency` に置換、デフォルト値テスト、範囲外値テスト（CHECK 制約発火）を追加
- [api/internal/testfactory/](../../api/internal/testfactory/): `CreatePriority` / `PriorityParams` を **削除**。`TaskParams` に `Importance` / `Urgency`（ゼロ値時は 1 にフォールバック）を追加

### 2.6 E2E シナリオ

- [api/e2e/scenarios/priorities.yaml](../../api/e2e/scenarios/priorities.yaml): **削除**
- [api/e2e/scenarios/tasks.yaml](../../api/e2e/scenarios/tasks.yaml): `priorityId: null` を `importance: 1, urgency: 1` などに置換、必要なら 1〜3 の境界値検証ステップを追加

### 2.7 Flutter ドメイン層

- [app/lib/domain/models/priority.dart](../../app/lib/domain/models/priority.dart): **削除**
- [app/lib/domain/models/task.dart](../../app/lib/domain/models/task.dart):
  - `priorityId` / `priority`（解決済みオブジェクト）フィールドを **削除**
  - `int importance` / `int urgency` を追加（NOT NULL、デフォルト 1）
  - `copyWith` の `clearPriorityId` / `clearPriority` を削除
- [app/lib/domain/repositories/priority_repository.dart](../../app/lib/domain/repositories/priority_repository.dart): **削除**
- [app/lib/domain/repositories/task_repository.dart](../../app/lib/domain/repositories/task_repository.dart):
  - `TaskFilter.priorityIds: List<String>` を `importanceLevels: Set<int>` / `urgencyLevels: Set<int>` に置換
  - `SortField.priority` を `importance` / `urgency` に置換
  - `addTask` / `updateTask` の `priorityId` パラメータを `importance: int` / `urgency: int` に置換

### 2.8 Flutter データ層

- [app/lib/data/repositories/priority_repository_impl.dart](../../app/lib/data/repositories/priority_repository_impl.dart): **削除**
- [app/lib/data/repositories/task_repository_impl.dart](../../app/lib/data/repositories/task_repository_impl.dart):
  - JSON 読み込みで `priorityId` の代わりに `importance` / `urgency` を取得
  - フィルタロジックを `importanceLevels` / `urgencyLevels` ベースに変更
  - ソートを `importance` / `urgency`（int 比較、降順がデフォルト）に変更

### 2.9 Flutter プロバイダ / UI

- [app/lib/presentation/providers/priority_provider.dart](../../app/lib/presentation/providers/priority_provider.dart): **削除**
- [app/lib/presentation/providers/task_provider.dart](../../app/lib/presentation/providers/task_provider.dart):
  - `priorityNotifierProvider` の watch / `priorityMap` でのハイドレーション処理を削除（解決不要、整数値そのまま使う）
  - `addTask` / `updateTask` の引数を `importance` / `urgency` に変更
- [app/lib/presentation/providers/filter_provider.dart](../../app/lib/presentation/providers/filter_provider.dart): `setPriorityIds` を `setImportanceLevels` / `setUrgencyLevels` に置換
- [app/lib/presentation/providers/websocket_provider.dart](../../app/lib/presentation/providers/websocket_provider.dart): `priority.changed` 分岐を削除（重要度・緊急度はタスクに内包されるので `task.changed` で十分）
- [app/lib/presentation/pages/task_form/task_form_page.dart](../../app/lib/presentation/pages/task_form/task_form_page.dart):
  - 優先度ドロップダウン（215-227行目）を 2 つの「重要度」「緊急度」セレクタに分割
  - 各セレクタは 1=低 / 2=中 / 3=高 の 3 択固定（DropdownButtonFormField または SegmentedButton）
- [app/lib/presentation/pages/task_list/widgets/filter_bar.dart](../../app/lib/presentation/pages/task_list/widgets/filter_bar.dart): フィルタチップ群を「重要度: 高/中/低」「緊急度: 高/中/低」の 2 セットに分割
- [app/lib/presentation/pages/task_list/widgets/task_card.dart](../../app/lib/presentation/pages/task_list/widgets/task_card.dart): `_PriorityChip` を `_ImportanceChip` / `_UrgencyChip` に分割。ラベルは「重要度: 高」など
- [app/lib/presentation/pages/settings/settings_page.dart](../../app/lib/presentation/pages/settings/settings_page.dart): `_PrioritySettings` セクションと優先度マスタ管理 UI を **削除**（マスター管理不要）
- [app/lib/core/constants/app_constants.dart](../../app/lib/core/constants/app_constants.dart): `defaultPriorities` を **削除**（マスタ不要）。代わりに UI で使う表示ラベル定数 `importanceLabels = {1: '低', 2: '中', 3: '高'}` / `urgencyLabels = {1: '低', 2: '中', 3: '高'}` を追加
- 初回ログイン時に `defaultPriorities` をシードしている処理があれば **削除**

### 2.10 ドキュメント

- [README.md](../../README.md): API エンドポイント表から `/priorities` を削除し、Task の説明に「重要度・緊急度（1〜3）」を追記
- [docs/architecture.md](../architecture.md): 図と説明の優先度参照を更新（Priority モデル削除、Task に importance/urgency 列追加）
- [docs/specification.md](../specification.md): 該当箇所があれば更新

---

## 3. 実装順序

依存関係を考慮した順序。各ステップ完了時にビルド/型チェックが通る状態を保つ。

### Step 1: スキーマ層

1. [schema.sql](../../schema.sql) を編集: `priorities` テーブル削除、`tasks.priority_id` 削除、`importance` / `urgency` カラムと CHECK 制約を追加
2. [spec/main.tsp](../../spec/main.tsp) を編集: `Priority*` / `PriorityOps` 削除、`Task` 系モデルのフィールド置換
3. [api/internal/db/queries/priorities.sql](../../api/internal/db/queries/priorities.sql) を削除し、[tasks.sql](../../api/internal/db/queries/tasks.sql) を更新

### Step 2: コード生成

4. `mise run gen` で TypeSpec → ogen と sqlc を再生成
5. `mise run db:migrations:create` でマイグレーション生成

### Step 3: Go バックエンド

6. [api/internal/handler/convert.go](../../api/internal/handler/convert.go): `toAPIPriority` 削除、Task 変換関数のフィールド置換
7. [api/internal/handler/priorities.go](../../api/internal/handler/priorities.go) を削除
8. [api/internal/handler/tasks.go](../../api/internal/handler/tasks.go) を更新: 1〜3 範囲バリデーション、デフォルト 1 適用
9. ハンドラ登録（cmd/server/main.go や handler.go の構造体配線）が ogen 生成インターフェイス変更により自動的にコンパイルエラーで指摘される。要修正

### Step 4: テスト

10. [api/internal/testfactory/](../../api/internal/testfactory/): `CreatePriority` 削除、`TaskParams` 拡張
11. [api/internal/repository-test/priorities_test.go](../../api/internal/repository-test/priorities_test.go) を削除
12. [api/internal/repository-test/tasks_test.go](../../api/internal/repository-test/tasks_test.go) を更新（デフォルト値・範囲外 CHECK 制約のテストを追加）
13. E2E: [api/e2e/scenarios/priorities.yaml](../../api/e2e/scenarios/priorities.yaml) 削除、[tasks.yaml](../../api/e2e/scenarios/tasks.yaml) 更新

### Step 5: Flutter

14. ドメイン層: [priority.dart](../../app/lib/domain/models/priority.dart) / [priority_repository.dart](../../app/lib/domain/repositories/priority_repository.dart) 削除
15. [task.dart](../../app/lib/domain/models/task.dart) を更新（`importance` / `urgency` int フィールド）
16. [task_repository.dart](../../app/lib/domain/repositories/task_repository.dart) のフィルタ・ソート・引数を更新
17. データ層: [priority_repository_impl.dart](../../app/lib/data/repositories/priority_repository_impl.dart) 削除、[task_repository_impl.dart](../../app/lib/data/repositories/task_repository_impl.dart) 更新
18. プロバイダ: [priority_provider.dart](../../app/lib/presentation/providers/priority_provider.dart) 削除、[task_provider.dart](../../app/lib/presentation/providers/task_provider.dart) / [filter_provider.dart](../../app/lib/presentation/providers/filter_provider.dart) / [websocket_provider.dart](../../app/lib/presentation/providers/websocket_provider.dart) を更新
19. UI: [task_form_page.dart](../../app/lib/presentation/pages/task_form/task_form_page.dart) / [filter_bar.dart](../../app/lib/presentation/pages/task_list/widgets/filter_bar.dart) / [task_card.dart](../../app/lib/presentation/pages/task_list/widgets/task_card.dart) / [settings_page.dart](../../app/lib/presentation/pages/settings/settings_page.dart) を更新
20. [app_constants.dart](../../app/lib/core/constants/app_constants.dart) を更新（`defaultPriorities` 削除、表示ラベル定数追加）
21. Riverpod 生成コードが必要なら `dart run build_runner build`

### Step 6: ドキュメント

22. README.md / architecture.md / specification.md を更新

### Step 7: 検証

23. `cd api && go build ./...`
24. `cd api && go test ./internal/repository-test/...`
25. `cd app && flutter analyze`
26. （任意）E2E: `cd api && go test ./e2e/...`

---

## 4. 設計判断

### 4.1 なぜマスターテーブルを持たないか

1〜3 の固定スケールにする方針なので、ユーザーごとに値を CRUD する必要がなく、`importances` / `urgencies` テーブルを用意する意味が薄い。`tasks` テーブルに直接 INT 列を持たせるのが最もシンプル。表示ラベル（高/中/低）はクライアント側の定数で十分。

### 4.2 値の向き（1=低 / 2=中 / 3=高）

ユーザー指定。直感的に「数値が大きい方が重要・緊急」という 5 段階評価スタイル。ソート時は降順がデフォルトとなる（重要・緊急なものを上に）。

### 4.3 NOT NULL DEFAULT 1

ユーザー指定。「未設定」状態を排し、必ず何らかの値を持つ。新規タスクのデフォルトは 1（低）。これにより、UI も常に値を持つ前提で設計でき、null チェックが不要。

### 4.4 CHECK 制約

DB レベルで 1〜3 を強制することで、API バグ・直接 SQL 実行・将来の別クライアントなど経由でも不整合データが入らない。アプリ層でも同じバリデーションを行う（多層防御）。

### 4.5 WebSocket イベント

重要度・緊急度はタスクに内包される値であり独立した CRUD を持たないため、`priority.changed` イベントは廃止。タスクの編集として `task.changed` イベントだけで通知される。

### 4.6 マイグレーション戦略

`schema.sql` に CHECK 制約を含めて記述すれば Atlas が DROP TABLE / DROP COLUMN / ADD COLUMN を含む単一マイグレーションを自動生成する。ローカル DB は `mise run db:migrate` で再生成される前提。

---

## 5. リスク / 留意点

- **ogen / sqlc 生成ファイル**: 編集禁止。`spec/main.tsp` と `schema.sql` / `queries/` のみを編集する。
- **Riverpod コード生成**: `*.g.dart` ファイルが影響を受けるため、ドメイン変更後に `dart run build_runner build --delete-conflicting-outputs` の実行が必要かもしれない。
- **WebSocket クライアント分岐**: [websocket_provider.dart](../../app/lib/presentation/providers/websocket_provider.dart) の `priority.changed` 分岐削除を忘れないこと。
- **`defaultPriorities` シード処理**: もしユーザー作成時に自動投入する処理があれば削除する。
- **API バリデーション**: ハンドラ層で 1〜3 の範囲外を `400 Bad Request` で弾く実装を忘れないこと（DB CHECK 制約に頼ると 500 になりうる）。
- **TypeSpec の int32**: ogen で int32 が生成される。1〜3 の制約は OpenAPI の `minimum` / `maximum` を TypeSpec デコレータ（`@minValue` / `@maxValue`）で表現できるかは要確認。実用上、ハンドラでの範囲チェックがあれば十分。
