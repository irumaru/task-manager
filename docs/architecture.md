# アーキテクチャガイド（開発者向け）

## 1. 全体構成

このアプリは **オンライン専用のクラウドアーキテクチャ** を採用しています。ローカルDBは使用せず、すべてのデータは Go API 経由でクラウドに保存されます。

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter App（クライアント）                                    │
│                                                                │
│  Presentation 層（画面・状態管理）                              │
│    lib/presentation/                                           │
│      pages/      ← 画面（UI）                                 │
│      widgets/    ← 再利用可能な部品                           │
│      providers/  ← 状態管理（Riverpod）                      │
│  ─────────────────────────────────────────────────────────    │
│  Domain 層（ビジネスロジック・抽象）                            │
│    lib/domain/                                                 │
│      models/       ← Task, Priority, Status, Tag（ID は UUID）│
│      repositories/ ← リポジトリのインターフェース（abstract） │
│  ─────────────────────────────────────────────────────────    │
│  Data 層（API 通信の実装）                                     │
│    lib/data/                                                   │
│      api/          ← dio クライアント・WebSocket クライアント │
│      repositories/ ← リポジトリの実装（API 呼び出し）        │
└────────────────────────────┬───────────────────────────────────┘
                             │ HTTPS / WSS
                             ▼
┌────────────────────────────────────────────────────────────────┐
│  Go API（サーバー）                                             │
│    api/                                                        │
│      REST エンドポイント（タスク・優先度・ステータス・タグ CRUD）│
│      WebSocket（リアルタイム同期）                             │
│      JWT 認証（Google ID Token 検証）                          │
└────────────────────────────┬───────────────────────────────────┘
                             │
                             ▼
                      PostgreSQL（クラウドDB）

  lib/core/       ← 定数・テーマ・ユーティリティ（全層から使用）
```

> **なぜ 3 層？**
> 画面（Presentation）がAPI通信（Data）を直接触ると、変更に弱くなります。間に Domain 層を挟むことで、「APIの実装を変えても画面のコードは変えなくていい」という設計にしています。

> **詳細なクラウド設計は [cloud-design.md](cloud-design.md) を参照してください。**

---

## 2. ディレクトリ構造

**Flutter クライアント（app/）**

```
app/lib/
├── main.dart                        ← エントリーポイント
├── app.dart                         ← MaterialApp + 画面ルーティング（認証ガード含む）
│
├── core/
│   ├── constants/app_constants.dart ← アプリ名・デフォルトデータ定義
│   ├── theme/app_theme.dart         ← ライト・ダークテーマ
│   └── utils/date_utils.dart        ← 日付フォーマット等のユーティリティ
│
├── domain/
│   ├── models/
│   │   ├── task.dart                ← Task クラス（id: String UUID）
│   │   ├── priority.dart            ← Priority クラス（id: String UUID）
│   │   ├── status.dart              ← Status クラス（id: String UUID）
│   │   └── tag.dart                 ← Tag クラス（id: String UUID）
│   └── repositories/
│       ├── task_repository.dart     ← TaskRepository インターフェース
│       ├── priority_repository.dart ← PriorityRepository インターフェース
│       ├── status_repository.dart   ← StatusRepository インターフェース
│       └── tag_repository.dart      ← TagRepository インターフェース
│
├── data/
│   ├── api/
│   │   ├── api_client.dart          ← dio ラッパー（JWT 自動付与・エラー処理）
│   │   └── websocket_client.dart    ← WebSocket 接続・再接続管理
│   └── repositories/
│       ├── task_repository_impl.dart        ← API 経由の実装
│       ├── priority_repository_impl.dart
│       ├── status_repository_impl.dart
│       └── tag_repository_impl.dart
│
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart       ← Google サインイン状態・JWT 管理
    │   ├── websocket_provider.dart  ← WS 接続・イベント受信
    │   ├── api_provider.dart        ← ApiClient・リポジトリを Riverpod で提供
    │   ├── task_provider.dart       ← タスク一覧取得・CRUD 操作
    │   ├── filter_provider.dart     ← フィルタ・ソート状態
    │   ├── priority_provider.dart
    │   ├── status_provider.dart
    │   └── tag_provider.dart
    ├── pages/
    │   ├── login/
    │   │   └── login_page.dart      ← Google サインイン画面
    │   ├── task_list/
    │   │   ├── task_list_page.dart  ← タスク一覧画面
    │   │   └── widgets/
    │   │       ├── task_card.dart   ← タスクカード
    │   │       └── filter_bar.dart  ← フィルタ・ソートバー
    │   ├── task_form/
    │   │   └── task_form_page.dart  ← タスク追加・編集画面
    │   └── settings/
    │       └── settings_page.dart   ← 設定画面（優先度・ステータス・タグ管理）
    └── widgets/
        ├── confirm_dialog.dart      ← 削除確認ダイアログ
        └── empty_state.dart         ← タスクゼロ時の表示
```

**Go API サーバー（api/）**

```
api/
├── cmd/server/main.go               ← エントリーポイント
├── internal/
│   ├── api/                         ← ogen 自動生成（手動編集不要）
│   │   └── oas_*_gen.go             ← Handler IF・型・ルーター・SecurityHandler IF
│   ├── auth/
│   │   ├── google.go                ← Google ID Token 検証
│   │   ├── jwt.go                   ← JWT 発行・検証
│   │   └── security_handler.go      ← ogen SecurityHandler 実装（JWT 検証）
│   ├── handler/                     ← ogen Handler インターフェースの実装（手動で記述）
│   │   ├── auth_handler.go          ← POST /auth/google
│   │   ├── task_handler.go
│   │   ├── priority_handler.go
│   │   ├── status_handler.go
│   │   ├── tag_handler.go
│   │   └── websocket_handler.go     ← WS /ws（手動実装）
│   ├── repository/                  ← sqlc 自動生成（手動編集不要）
│   │   ├── db.go / models.go
│   │   └── *.sql.go
│   └── websocket/
│       ├── hub.go                   ← Hub インターフェース定義
│       └── local_hub.go             ← シングルサーバー実装（初期実装）
├── db/
│   ├── migrations/                  ← golang-migrate 管理（up/down ペア）
│   │   ├── 000001_init.up.sql
│   │   └── 000001_init.down.sql
│   └── queries/                     ← sqlc に渡す SQL クエリ
├── sqlc.yaml                        ← sqlc 設定
├── go.mod
└── Dockerfile
```

**リポジトリルート**

```
task-manager/
├── .mise.toml               ← ローカル CLI ツール管理（go・pnpm・ogen・sqlc・air・migrate）
├── pnpm-workspace.yaml      ← pnpm ワークスペース設定
├── spec/                    ← TypeSpec パッケージ（pnpm workspace メンバー）
│   ├── package.json         ← @typespec/compiler 等の依存
│   ├── main.tsp             ← API 定義（手動で記述）
│   └── tsp-output/
│       └── openapi.yaml     ← tsp compile で自動生成
├── docker-compose.yml
├── api/                     ← Go API サーバー
└── app/                     ← Flutter クライアント
```

---

## 3. 起動の流れ

```dart
// main.dart
void main() {
  runApp(
    const ProviderScope(   // ← Riverpod の有効化（アプリ全体を包む）
      child: App(),
    ),
  );
}
```

`App` クラスは `MaterialApp` を作り、認証状態に応じて画面を切り替えます。

```
main() → ProviderScope → App
                          ├── 未ログイン → LoginPage（Google Sign-In）
                          └── ログイン済み → MainShell
                                              ├── TaskListPage  （index=0）
                                              └── SettingsPage  （index=1）
```

ログイン後は WebSocket 接続が確立され、リアルタイム同期が有効になります。

---

## 4. 状態管理（Riverpod）の仕組み

Riverpod は「状態を管理する箱（Provider）」を定義し、Widget から参照する仕組みです。

### Provider の依存関係

```
authProvider               ← Google サインイン状態・JWT 管理
    └── apiClientProvider  ← dio（JWT ヘッダ自動付与）
            └── taskRepositoryProvider     ← TaskRepositoryImpl（API呼び出し）
            └── priorityRepositoryProvider
            └── statusRepositoryProvider
            └── tagRepositoryProvider

websocketProvider          ← WS 接続管理
    → イベント受信時に tasksProvider 等を invalidate

filterProvider             ← FilterState（検索クエリ・フィルタ・ソート）

tasksProvider              ← taskRepositoryProvider + filterProvider を watch
                              → フィルタを反映したタスク一覧を返す

taskNotifierProvider       ← addTask / updateTask / deleteTask を実行
                              → API 呼び出し後に tasksProvider を invalidate（再取得）
```

### Widget での使い方

```dart
// ConsumerWidget を使って Riverpod にアクセスする
class TaskListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: 値が変わると自動的に再描画される
    final tasksAsync = ref.watch(tasksProvider);

    // read: 一度だけ読む（ボタン押下時など）
    ref.read(filterProvider.notifier).setSearchQuery(query);
  }
}
```

### Provider の種類（このアプリで使われているもの）

| Provider の種類 | 用途 | 例 |
|---|---|---|
| `Provider` | 変更されない値・オブジェクトを提供 | `apiClientProvider`, `taskRepositoryProvider` |
| `FutureProvider` | 非同期で値を取得して提供 | `tasksProvider`（APIからタスク一覧を取得） |
| `NotifierProvider` | 状態を保持し変更メソッドも持つ | `filterProvider`（フィルタ状態） |
| `AsyncNotifierProvider` | 非同期操作を伴う状態変更 | `taskNotifierProvider`（CRUD） |

---

## 5. データの流れ（タスク一覧表示）

```
1. TaskListPage が tasksProvider を watch する
        ↓
2. tasksProvider が filterProvider と statusNotifierProvider を watch する
        ↓
3. filterState（検索・フィルタ・ソート）を組み立てる
   ※「完了」ステータスはデフォルトで excludeStatusIds に追加される
        ↓
4. taskRepositoryProvider.getTasks(filter, sortField, sortOrder) を呼ぶ
        ↓
5. TaskRepositoryImpl が ApiClient（dio）経由で GET /tasks にリクエスト
        ↓
6. Go API がフィルタ・ソートを適用して JSON レスポンスを返す
        ↓
7. レスポンスを Task ドメインモデルに変換して返す
        ↓
8. tasksProvider が List<Task> を返す → TaskListPage が再描画される
```

**リアルタイム更新フロー（WebSocket）**

```
他の端末でタスク追加
        ↓
Go API が WebSocket で { type: "task.created", data: {...} } を配信
        ↓
websocketProvider がイベントを受信
        ↓
ref.invalidate(tasksProvider) を呼ぶ
        ↓
tasksProvider が再実行 → TaskListPage が自動更新
```

---

## 6. データの流れ（タスク追加・更新・削除）

```
1. TaskFormPage でフォームを送信
        ↓
2. ref.read(taskNotifierProvider.notifier).addTask(...) を呼ぶ
        ↓
3. TaskNotifier が taskRepositoryProvider.addTask(...) を呼ぶ
        ↓
4. TaskRepositoryImpl が ApiClient 経由で POST /tasks にリクエスト
        ↓
5. Go API がDB に INSERT し、WebSocket で全クライアントに task.created を配信
        ↓
6. TaskNotifier が ref.invalidate(tasksProvider) を呼ぶ（自端末の即時更新）
        ↓
7. tasksProvider が再実行され、TaskListPage が自動更新される
```

---

## 7. データモデル（Domain）

```dart
// domain/models/task.dart
class Task {
  final String id;           // UUID（クラウドDBのPK）
  final String title;
  final DateTime? dueDate;   // null = 期限なし
  final Priority? priority;  // null = 優先度未設定
  final Status? status;      // null = ステータス未設定
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

`Priority`, `Status`, `Tag` も同様に `id: String`（UUID）です。`TaskFilter` の ID リストも `List<String>` を使います。

`copyWith()` メソッドで特定フィールドだけ変えた新しいインスタンスを作れます（Dart では `final` フィールドを直接変更できないため）。

---

## 8. データベース（PostgreSQL）

データベースは Go API サーバー側の PostgreSQL です。Flutter アプリからは直接アクセスしません。

詳細なスキーマ（CREATE TABLE 文・ER 図）は [cloud-design.md](cloud-design.md#3-postgresql-スキーマ) を参照してください。

### スキーマの概要

| テーブル | 説明 |
|--------|------|
| `users` | Google 認証ユーザー（google_sub でユニーク） |
| `priorities` | 優先度（ユーザーごと） |
| `statuses` | ステータス（ユーザーごと） |
| `tags` | タグ（ユーザーごと・名前はユーザー内でユニーク） |
| `tasks` | タスク（ユーザーごと） |
| `task_tags` | タスク↔タグの多対多中間テーブル |

すべての PK は UUID です。`user_id` FK により各ユーザーのデータが分離されています。

---

## 9. リポジトリパターン

### なぜインターフェースと実装を分けるのか

```dart
// domain/repositories/task_repository.dart（インターフェース）
abstract class TaskRepository {
  Future<List<Task>> getTasks({...});
  Future<int> addTask({...});
  // ...
}

// data/repositories/task_repository_impl.dart（実装）
class TaskRepositoryImpl implements TaskRepository {
  final ApiClient _api;
  TaskRepositoryImpl(this._api);
  // dio を使った API 呼び出し
}
```

この分離により：
- **テストのしやすさ**: 本物のAPIを使わず、モック実装に差し替えられる
- **拡張性**: API の実装を変えても、Impl だけ変えれば済む
- **Presentation 層の単純化**: Provider は `TaskRepository` 型だけ知ればよい

---

## 10. フィルタリングの仕組み

```dart
// domain/repositories/task_repository.dart
class TaskFilter {
  final List<String> tagIds;           // 絞り込みタグID（UUID）
  final List<String> priorityIds;      // 絞り込み優先度ID（UUID）
  final List<String> statusIds;        // 絞り込みステータスID（UUID）
  final List<String> excludeStatusIds; // 除外ステータスID（「完了」非表示に使用）
  final bool? isOverdue;               // 期限切れのみ
  final String searchQuery;            // タイトル検索
}
```

- `tasksProvider` が `filterProvider` の変更を監視し、フィルタが変わると自動的にタスク一覧を再取得します
- フィルタはすべてクエリパラメータとして Go API に渡され、サーバー側で処理されます

---

## 11. 拡張ポイント

| 拡張内容 | 変更が必要な箇所 |
|---|---|
| 新しいフィルタ条件 | `TaskFilter` にフィールド追加 → Go API のクエリパラメータ対応 → `FilterNotifier` にメソッド追加 |
| 新しい画面 | `pages/` に追加し、`app.dart` でルーティング設定 |
| DBスキーマ変更 | `api/db/migrations/` に新しいマイグレーションファイルを追加 |
| 新しい WebSocket イベント | Go `hub.go` にイベント種別追加 → Flutter `websocket_provider.dart` に処理追加 |
| マルチサーバー対応 | `websocket/redis_hub.go` を実装し `main.go` で `LocalHub` と差し替え |
