# Flutter クラウド対応 実装計画

## 概要

現在の drift (SQLite) ベースのローカル実装を、Go API（REST + WebSocket）経由のクラウドベースに全面移行します。

```
現在:  Flutter → drift (SQLite) → ローカルファイル
移行後: Flutter → 生成APIクライアント (dio) → Go API → PostgreSQL
```

### コード生成ツールチェーン

```
spec/tsp-output/openapi.yaml
    ↓ cd app && pnpm generate  (openapi-generator-cli / dart-dio)
app/lib/data/generated/api/      ← 自動生成（手動編集不要）
    ├── api/tasks_api.dart
    ├── api/auth_api.dart
    ├── model/task.dart
    └── ...

app/lib/data/api/
    └── api_client.dart          ← dio + JWT interceptor（手動で記述）
    └── websocket_client.dart    ← WebSocket クライアント（手動で記述）

app/lib/data/repositories/      ← 生成クライアントをラップ（手動で記述）
    └── task_repository_impl.dart
```

生成コマンド（`mise run app:generate`）:
```bash
cd app && pnpm generate
# → openapi-generator-cli generate \
#     -i ../spec/tsp-output/openapi.yaml \
#     -g dart-dio \
#     -o lib/data/generated/api
```

---

## Step 1: `pubspec.yaml` パッケージ差し替え

**削除:**
```yaml
# dependencies
drift: ...
sqlite3_flutter_libs: ...
path_provider: ...
path: ...

# dev_dependencies
drift_dev: ...
```

**追加:**
```yaml
dependencies:
  google_sign_in: ^6.2.0
  flutter_secure_storage: ^9.0.0
  dio: ^5.7.0
  web_socket_channel: ^3.0.0
```

> 生成クライアントが依存する `dio` は openapi-generator が `pubspec.yaml` に自動追記するため、
> 手動での追加は不要になる場合があります。

---

## Step 2: OpenAPI クライアントコードを生成

spec をコンパイルしてからクライアントを生成します。

```bash
# 1. TypeSpec → OpenAPI
cd spec && pnpm compile

# 2. OpenAPI → Dart/dio クライアント
mise run app:generate
```

生成物（`app/lib/data/generated/api/`）は手動編集不可。spec が変わったら再生成します。

---

## Step 3: ドメインモデルの ID 型変更 (`int` → `String`)

生成クライアントのモデル（`generated/api/model/`）はリポジトリ層でのみ使用し、
アプリ内部では既存のドメインモデルを引き続き使います。
ただし ID の型を `int` → `String`（UUID）に変更する必要があります。

### 変更対象ファイル

| ファイル | 変更内容 |
|---|---|
| `domain/models/task.dart` | `int id` → `String id`、`copyWith` も同様 |
| `domain/models/priority.dart` | `int id` → `String id` |
| `domain/models/status.dart` | `int id` → `String id` |
| `domain/models/tag.dart` | `int id` → `String id` |
| `domain/repositories/task_repository.dart` | `TaskFilter` の `List<int>` → `List<String>`、メソッド引数も全て `int` → `String` |
| `domain/repositories/priority_repository.dart` | `int id` → `String id` |
| `domain/repositories/status_repository.dart` | `int id` → `String id` |
| `domain/repositories/tag_repository.dart` | `int id` → `String id` |

### 変更例

```dart
// 変更前
class Task {
  final int id;
  ...
}

class TaskFilter {
  final List<int> tagIds;
  final List<int> priorityIds;
  ...
}

// 変更後
class Task {
  final String id;  // UUID
  ...
}

class TaskFilter {
  final List<String> tagIds;
  final List<String> priorityIds;
  ...
}
```

---

## Step 4: `data/database/` ディレクトリを削除

drift 関連ファイルをすべて削除:

```
app/lib/data/database/
├── app_database.dart       ← 削除
├── app_database.g.dart     ← 削除
└── tables/                 ← 削除
    ├── priorities_table.dart
    ├── statuses_table.dart
    ├── tags_table.dart
    ├── task_tags_table.dart
    └── tasks_table.dart
```

---

## Step 5: `core/constants/app_constants.dart` に API URL 追加

```dart
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

const wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'ws://localhost:8080',
);
```

本番ビルド時:
```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_BASE_URL=wss://api.example.com
```

---

## Step 6: `data/api/` を新規作成

### `data/api/api_client.dart` — dio ラッパー

生成クライアントに渡す `Dio` インスタンスを構成します。

```dart
Dio buildDio(String token) {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // authProvider をログアウト状態へ
      }
      handler.next(error);
    },
  ));
  return dio;
}
```

### `data/api/websocket_client.dart` — WebSocket クライアント

- JWT をクエリパラメータ（`?token=<JWT>`）で送信
- 接続・切断・受信メッセージの `Stream` 提供
- 切断時の指数バックオフ自動再接続（1s → 2s → 4s → 最大 30s）

---

## Step 7: `data/repositories/` を API ベースに差し替え

生成クライアントをラップし、ドメインモデルへ変換します。

| ファイル | 変更内容 |
|---|---|
| `task_repository_impl.dart` | `TasksApi`（生成）を使用し、レスポンスをドメイン `Task` に変換 |
| `priority_repository_impl.dart` | `PrioritiesApi`（生成）を使用 |
| `status_repository_impl.dart` | `StatusesApi`（生成）を使用 |
| `tag_repository_impl.dart` | `TagsApi`（生成）を使用 |

### 実装例（TaskRepositoryImpl）

```dart
class TaskRepositoryImpl implements TaskRepository {
  final TasksApi _api;  // openapi-generator が生成したクライアント
  TaskRepositoryImpl(this._api);

  @override
  Future<List<Task>> getTasks({ TaskFilter filter = const TaskFilter(), ... }) async {
    final results = await _api.tasksGet(
      search: filter.searchQuery.isEmpty ? null : filter.searchQuery,
      priorityIds: filter.priorityIds.isEmpty ? null : filter.priorityIds.join(','),
      ...
    );
    return results.map(_toDomain).toList();
  }

  // 生成モデル → ドメインモデルへの変換
  Task _toDomain(GeneratedTask g) => Task(
    id: g.id,
    title: g.title,
    dueDate: g.dueDate,
    priority: g.priority == null ? null : Priority(id: g.priority!.id, ...),
    ...
  );
}
```

---

## Step 8: 認証レイヤーを追加

### `presentation/providers/auth_provider.dart` — 新規作成

```
AuthState
├── authenticated(token: String, user: User)
└── unauthenticated
```

- `google_sign_in` で Google Sign-In し ID Token を取得
- 生成クライアントの `AuthApi.authGooglePost()` で JWT を取得
- JWT を `flutter_secure_storage` に保存
- アプリ起動時に `flutter_secure_storage` から JWT を復元

### `presentation/pages/login/login_page.dart` — 新規作成

- Google Sign-In ボタン画面
- ログイン成功後 → `MainShell` へ遷移

---

## Step 9: `presentation/providers/` の再配線

`database_provider.dart` を **`api_provider.dart`** に置き換え:

```dart
// api_provider.dart
final _dioProvider = Provider<Dio>((ref) {
  final token = ref.watch(authProvider).token;
  return buildDio(token);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(TasksApi(ref.watch(_dioProvider)));
});

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  return PriorityRepositoryImpl(PrioritiesApi(ref.watch(_dioProvider)));
});

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepositoryImpl(StatusesApi(ref.watch(_dioProvider)));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepositoryImpl(TagsApi(ref.watch(_dioProvider)));
});
```

依存関係:
```
authProvider
  └── _dioProvider (dio + JWT interceptor)
        ├── taskRepositoryProvider     → tasksProvider
        ├── priorityRepositoryProvider → priorityNotifierProvider
        ├── statusRepositoryProvider   → statusNotifierProvider
        └── tagRepositoryProvider      → tagNotifierProvider
```

既存の `task_provider.dart`, `filter_provider.dart` 等は ID 型を `String` に変更するだけで、ロジックはほぼ流用可能。

---

## Step 10: WebSocket プロバイダーを追加

**`presentation/providers/websocket_provider.dart`** — 新規作成

```dart
final websocketProvider = Provider<WebSocketClient>((ref) {
  final token = ref.watch(authProvider).token;
  final ws = WebSocketClient(baseUrl: wsBaseUrl, token: token);
  ws.events.listen((event) {
    switch (event.type) {
      case 'task.created':
      case 'task.updated':
      case 'task.deleted':
        ref.invalidate(tasksProvider);
      case 'priority.created':
      case 'priority.updated':
      case 'priority.deleted':
        ref.invalidate(priorityNotifierProvider);
      case 'status.created':
      case 'status.updated':
      case 'status.deleted':
        ref.invalidate(statusNotifierProvider);
      case 'tag.created':
      case 'tag.updated':
      case 'tag.deleted':
        ref.invalidate(tagNotifierProvider);
    }
  });
  ref.onDispose(ws.close);
  return ws;
});
```

---

## Step 11: `app.dart` / `main.dart` の更新

### `app.dart` — ログイン状態による画面分岐

```dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      home: auth.isAuthenticated ? const MainShell() : const LoginPage(),
    );
  }
}
```

### `main.dart` — WebSocket 起動

```dart
void main() {
  runApp(
    ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        if (ref.watch(authProvider).isAuthenticated) {
          ref.watch(websocketProvider);
        }
        return const App();
      }),
    ),
  );
}
```

---

## 実装順序まとめ

```
1.  pubspec.yaml 差し替え          ← drift 削除・dio 等追加
2.  pnpm generate                  ← OpenAPI → Dart クライアント生成
3.  ドメインモデル・リポジトリI/F  ← int → String
4.  data/database/ 削除
5.  core/constants/ 更新           ← API_BASE_URL / WS_BASE_URL
6.  data/api/ 作成                 ← ApiClient (dio設定), WebSocketClient
7.  data/repositories/ 差し替え    ← 生成クライアントをラップ
8.  auth_provider + login_page     ← 認証レイヤー
9.  api_provider.dart              ← database_provider 置き換え
10. task/filter 等 provider 調整   ← int → String
11. websocket_provider             ← リアルタイム同期
12. app.dart / main.dart 更新      ← ログイン分岐
```

---

## エラーハンドリング方針

オンライン専用のため、接続エラー時はエラー UI を表示してリトライを促します。

| エラー | UI 対応 |
|--------|---------|
| 未認証（401） | ログイン画面にリダイレクト |
| ネットワークエラー | スナックバーでエラー表示 + リトライボタン |
| サーバーエラー（5xx） | スナックバーでエラー表示 |
| WS 切断 | 自動再接続（指数バックオフ） |
