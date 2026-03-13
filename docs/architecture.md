# アーキテクチャガイド（開発者向け）

## 1. 全体構成

このアプリは **3層アーキテクチャ** を採用しています。Flutter 初心者向けに、まず全体像を把握してください。

```
┌────────────────────────────────────────────────────────────────┐
│  Presentation 層（画面・状態管理）                              │
│  lib/presentation/                                             │
│    pages/      ← 画面（UI）                                    │
│    widgets/    ← 再利用可能な部品                              │
│    providers/  ← 状態管理（Riverpod）                         │
├────────────────────────────────────────────────────────────────┤
│  Domain 層（ビジネスロジック・抽象）                            │
│  lib/domain/                                                   │
│    models/       ← データクラス（Task, Priority, Status, Tag） │
│    repositories/ ← リポジトリのインターフェース（abstract）    │
├────────────────────────────────────────────────────────────────┤
│  Data 層（データの実装）                                        │
│  lib/data/                                                     │
│    database/     ← drift（SQLite）のテーブル定義・DB クラス   │
│    repositories/ ← リポジトリの実装（実際のDB操作）           │
└────────────────────────────────────────────────────────────────┘

  lib/core/       ← 定数・テーマ・ユーティリティ（全層から使用）
```

> **なぜ 3 層？**
> 画面（Presentation）がデータベース（Data）を直接触ると、変更に弱くなります。間に Domain 層を挟むことで、「DBを変えても画面のコードは変えなくていい」という設計にしています。

---

## 2. ディレクトリ構造

```
app/lib/
├── main.dart                        ← エントリーポイント
├── app.dart                         ← MaterialApp + 画面ルーティング
│
├── core/
│   ├── constants/app_constants.dart ← アプリ名・デフォルトデータ定義
│   ├── theme/app_theme.dart         ← ライト・ダークテーマ
│   └── utils/date_utils.dart        ← 日付フォーマット等のユーティリティ
│
├── domain/
│   ├── models/
│   │   ├── task.dart                ← Task クラス
│   │   ├── priority.dart            ← Priority クラス
│   │   ├── status.dart              ← Status クラス
│   │   └── tag.dart                 ← Tag クラス
│   └── repositories/
│       ├── task_repository.dart     ← TaskRepository インターフェース
│       ├── priority_repository.dart ← PriorityRepository インターフェース
│       ├── status_repository.dart   ← StatusRepository インターフェース
│       └── tag_repository.dart      ← TagRepository インターフェース
│
├── data/
│   ├── database/
│   │   ├── app_database.dart        ← AppDatabase クラス（drift）
│   │   ├── app_database.g.dart      ← コード生成ファイル（触らない）
│   │   └── tables/
│   │       ├── tasks_table.dart
│   │       ├── priorities_table.dart
│   │       ├── statuses_table.dart
│   │       ├── tags_table.dart
│   │       └── task_tags_table.dart ← タスク↔タグの中間テーブル
│   └── repositories/
│       ├── task_repository_impl.dart
│       ├── priority_repository_impl.dart
│       ├── status_repository_impl.dart
│       └── tag_repository_impl.dart
│
└── presentation/
    ├── providers/
    │   ├── database_provider.dart   ← DB・リポジトリを Riverpod で提供
    │   ├── task_provider.dart       ← タスク一覧取得・CRUD 操作
    │   ├── filter_provider.dart     ← フィルタ・ソート状態
    │   ├── priority_provider.dart
    │   ├── status_provider.dart
    │   └── tag_provider.dart
    ├── pages/
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

`App` クラスは `MaterialApp` を作り、`MainShell` でボトムナビゲーション（タスク画面 / 設定画面）を管理します。

```
main() → ProviderScope → App → MainShell
                                  ├── TaskListPage  （index=0）
                                  └── SettingsPage  （index=1）
```

---

## 4. 状態管理（Riverpod）の仕組み

Riverpod は「状態を管理する箱（Provider）」を定義し、Widget から参照する仕組みです。

### Provider の依存関係

```
databaseProvider          ← AppDatabase（SQLite接続）
    └── taskRepositoryProvider  ← TaskRepositoryImpl（DB操作の実装）
    └── priorityRepositoryProvider
    └── statusRepositoryProvider
    └── tagRepositoryProvider

filterProvider            ← FilterState（検索クエリ・フィルタ・ソート）

tasksProvider             ← taskRepositoryProvider + filterProvider を watch
                             → フィルタを反映したタスク一覧を返す

taskNotifierProvider      ← addTask / updateTask / deleteTask を実行
                             → 完了後に tasksProvider を invalidate（再取得）
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
| `Provider` | 変更されない値・オブジェクトを提供 | `databaseProvider`, `taskRepositoryProvider` |
| `FutureProvider` | 非同期で値を取得して提供 | `tasksProvider`（DBからタスク一覧を取得） |
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
5. TaskRepositoryImpl が AppDatabase（drift/SQLite）に SQL クエリを発行
        ↓
6. DB から TaskData（生データ）を取得し、Task ドメインモデルに変換して返す
        ↓
7. tasksProvider が List<Task> を返す → TaskListPage が再描画される
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
4. TaskRepositoryImpl が drift 経由で INSERT を実行
        ↓
5. TaskNotifier が ref.invalidate(tasksProvider) を呼ぶ
        ↓
6. tasksProvider が再実行され、TaskListPage が自動更新される
```

---

## 7. データモデル（Domain）

```dart
// domain/models/task.dart
class Task {
  final int id;
  final String title;
  final DateTime? dueDate;   // null = 期限なし
  final Priority? priority;  // null = 優先度未設定
  final Status? status;      // null = ステータス未設定
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

`copyWith()` メソッドで特定フィールドだけ変えた新しいインスタンスを作れます（Dart では `final` フィールドを直接変更できないため）。

---

## 8. データベース（drift）

drift は SQLite を型安全に扱うための ORM（Object-Relational Mapper）です。

### テーブル定義

```dart
// data/database/tables/tasks_table.dart
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priorityId => integer().nullable().references(Priorities, #id)();
  IntColumn get statusId => integer().nullable().references(Statuses, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

### ER 図

```
priorities          statuses
┌──────────┐        ┌──────────┐
│ id (PK)  │        │ id (PK)  │
│ name     │        │ name     │
│ sortOrder│        │ sortOrder│
│ isDefault│        │ isDefault│
└────┬─────┘        └────┬─────┘
     │ FK                │ FK
     └──────┬────────────┘
            ▼
          tasks
     ┌────────────┐
     │ id (PK)    │
     │ title      │
     │ dueDate    │
     │ priorityId │
     │ statusId   │
     │ createdAt  │
     │ updatedAt  │
     └─────┬──────┘
           │ FK（task_id）
           ▼
        task_tags          tags
     ┌──────────────┐    ┌──────────┐
     │ task_id (FK) │    │ id (PK)  │
     │ tag_id (FK)  │───▶│ name     │
     └──────────────┘    └──────────┘
```

### コード生成

drift はテーブル定義から自動的に型安全なクエリコードを生成します。

```bash
# コード生成コマンド（テーブル定義を変更したら実行）
flutter pub run build_runner build
```

生成されたファイルは `app_database.g.dart` です（手動編集不要）。

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
  final AppDatabase _db;
  TaskRepositoryImpl(this._db);
  // drift を使った実際のDB操作
}
```

この分離により：
- **テストのしやすさ**: 本物のDBを使わず、モック実装に差し替えられる
- **拡張性**: 将来クラウドDBに変える場合も、Impl だけ変えれば済む
- **Presentation 層の単純化**: Provider は `TaskRepository` 型だけ知ればよい

---

## 10. フィルタリングの仕組み

```dart
// domain/repositories/task_repository.dart
class TaskFilter {
  final List<int> tagIds;         // 絞り込みタグID
  final List<int> priorityIds;    // 絞り込み優先度ID
  final List<int> statusIds;      // 絞り込みステータスID
  final List<int> excludeStatusIds; // 除外ステータスID（「完了」非表示に使用）
  final bool? isOverdue;          // 期限切れのみ
  final String searchQuery;       // タイトル検索
}
```

- `tasksProvider` が `filterProvider` の変更を監視し、フィルタが変わると自動的にタスク一覧を再取得します
- タグフィルタのみ DB クエリではなく Dart 側でフィルタリングしています（中間テーブル構造のため）

---

## 11. コード生成が必要な場合

以下を変更した場合は `build_runner` を実行してください。

| 変更内容 | 対象ファイル |
|---|---|
| drift テーブル定義の変更 | `data/database/tables/*.dart` |
| `AppDatabase` の変更 | `data/database/app_database.dart` |
| Riverpod `@riverpod` アノテーションの追加（将来） | `providers/*.dart` |

```bash
# 一度だけ生成
flutter pub run build_runner build

# ファイル変更を監視して自動生成
flutter pub run build_runner watch
```

---

## 12. 今後の拡張ポイント

| 拡張内容 | 変更が必要な箇所 |
|---|---|
| クラウド同期の追加 | `TaskRepository` の新 Impl を作り、`database_provider.dart` で差し替え |
| 新しいフィルタ条件 | `TaskFilter` にフィールド追加 → `TaskRepositoryImpl.getTasks()` にクエリ追加 → `FilterNotifier` にメソッド追加 |
| 新しい画面 | `pages/` に追加し、`app.dart` でルーティング設定 |
| DBスキーマ変更 | テーブル定義変更 → `schemaVersion` を上げる → `MigrationStrategy` にマイグレーション追加 |
