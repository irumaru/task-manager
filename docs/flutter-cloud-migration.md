# Flutter クラウド対応 実装計画

## 概要

現在のFlutterアプリはローカルDB（drift/SQLite）を使用しています。これを Go API 経由のクラウドアーキテクチャに移行します。

### 現状 → 目標

```
現状:  Flutter → drift（SQLite）→ ローカルファイル
目標:  Flutter → dio（HTTP）→ Go API → PostgreSQL
                  WebSocket → リアルタイム同期
```

### 主要な変更点

| 項目 | 現状 | 移行後 |
|------|------|--------|
| ID の型 | `int`（autoIncrement） | `String`（UUID） |
| データ層 | drift（SQLite） | dio（REST API） |
| 認証 | なし | Google Sign-In + JWT |
| リアルタイム同期 | なし | WebSocket |

### API クライアントの方針

Flutter 側の API クライアントは **手書きの dio クライアント** を使用します。

OpenAPI コード生成ツール（openapi-generator-cli の dart-dio 等）は、Dart 3.8+ との互換性問題が未解決のため採用しません。API は 5 リソース × CRUD の 16 エンドポイントと小規模であり、手書きでも十分対応可能です。

```
spec/main.tsp                       ← API 仕様（手書き・唯一の情報源）
    ↓ tsp compile
spec/tsp-output/openapi.yaml        ← OpenAPI spec（自動生成）
    ↓ ogen（Go 側のみコード生成）
api/internal/api/                    ← Go サーバーコード（自動生成）

app/lib/data/api/api_client.dart     ← Flutter 側は手書き（openapi.yaml を参照して実装）
```

---

## Step 1: パッケージ変更

### 削除するパッケージ

```yaml
# pubspec.yaml から削除
dependencies:
  drift: ^2.23.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.5
  path: ^1.9.0

dev_dependencies:
  drift_dev: ^2.23.0
```

### 追加するパッケージ

```yaml
dependencies:
  # 認証
  google_sign_in: ^7.2.0
  flutter_secure_storage: ^10.0.0

  # HTTP クライアント
  dio: ^5.9.0

  # WebSocket
  web_socket_channel: ^3.0.3
```

### 既存パッケージの更新

```yaml
dependencies:
  # 状態管理（v2 → v3 メジャーアップデート）
  flutter_riverpod: ^2.6.1  →  ^3.3.1
  riverpod_annotation: ^2.6.1  →  ^4.0.2

dev_dependencies:
  # コード生成
  build_runner: ^2.4.14  →  ^2.12.2
  riverpod_generator: ^2.6.3  →  ^4.0.3
```

> `cupertino_icons: ^1.0.8` と `flutter_lints: ^6.0.0` は最新のため変更不要です。

### Riverpod v3 の破壊的変更

flutter_riverpod v2 → v3 で以下の変更が必要です。クラウド対応と同時に対応します。

| 変更点 | 対応 |
|--------|------|
| `StateProvider` / `StateNotifierProvider` が `legacy.dart` に移動 | `Notifier` / `AsyncNotifier` に移行（既存コードの大半はこれらを使用済み） |
| `Ref` のサブクラス廃止 | すべて `Ref` 型に統一 |
| `AsyncValue.valueOrNull` 削除 | `AsyncValue.value` を使用（エラー時は `null`） |
| `Provider.autoDispose()` 構文変更 | `Provider(isAutoDispose: true)` に変更 |
| Notifier が Provider rebuild 時に再生成される | `Ref.mounted` で破棄後のアクセスを防止 |

---

## Step 2: ドメインモデル変更

### ID の型を `int` → `String` に変更

すべてのドメインモデルで `id` を `String`（UUID）に変更します。

**変更対象ファイル:**

| ファイル | 変更内容 |
|---------|---------|
| `domain/models/task.dart` | `id: int` → `id: String` |
| `domain/models/priority.dart` | `id: int` → `id: String` |
| `domain/models/status.dart` | `id: int` → `id: String` |
| `domain/models/tag.dart` | `id: int` → `id: String` |
| `domain/repositories/task_repository.dart` | `TaskFilter` の `List<int>` → `List<String>`、メソッド引数の `int id` → `String id` |
| `domain/repositories/priority_repository.dart` | メソッド引数の `int` → `String` |
| `domain/repositories/status_repository.dart` | メソッド引数の `int` → `String` |
| `domain/repositories/tag_repository.dart` | メソッド引数の `int` → `String` |

### Task モデルに memo フィールド追加

API のレスポンスに `memo` フィールドがあるため、ドメインモデルにも追加します。

```dart
class Task {
  final String id;        // UUID
  final String title;
  final String? memo;     // 追加
  final DateTime? dueDate;
  final Priority? priority;
  final Status? status;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### リポジトリインターフェースの変更

API のスキーマに合わせて、リポジトリインターフェースを更新します。

```dart
// domain/repositories/task_repository.dart
abstract class TaskRepository {
  Future<List<Task>> getTasks({
    TaskFilter? filter,
    SortField? sortField,
    SortOrder? sortOrder,
  });
  Future<Task> getTaskById(String id);
  Future<Task> addTask({
    required String title,
    String? memo,
    DateTime? dueDate,
    required String statusId,
    String? priorityId,
    List<String>? tagIds,
  });
  Future<Task> updateTask({
    required String id,
    String? title,
    String? memo,
    DateTime? dueDate,
    String? statusId,
    String? priorityId,
    List<String>? tagIds,
  });
  Future<void> deleteTask(String id);
}
```

> **ポイント**: `addTask`/`updateTask` の引数が `priority: Priority` オブジェクトではなく `priorityId: String`（ID のみ）に変わります。API は ID を受け取るためです。

---

## Step 3: データ層の差し替え

### 削除

```
app/lib/data/database/         ← drift 関連ファイルを全削除
  app_database.dart
  app_database.g.dart
```

### 新規作成: API クライアント

```
app/lib/data/api/
├── api_client.dart            ← dio ラッパー（JWT 自動付与・全エンドポイント）
├── api_exception.dart         ← API エラーのラッパー
└── websocket_client.dart      ← WebSocket 接続管理（Step 6 で実装）
```

### `api_client.dart` の設計

dio を使った手書きクライアントです。OpenAPI spec（`spec/tsp-output/openapi.yaml`）を参照して各エンドポイントに対応するメソッドを実装します。

```dart
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient({required String baseUrl, required FlutterSecureStorage storage})
      : _storage = storage,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          contentType: 'application/json',
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // JWT 期限切れ → ログアウト処理を発火
        }
        handler.next(error);
      },
    ));
  }

  // ─── Auth ───

  /// POST /auth/google
  Future<Map<String, dynamic>> googleLogin(String idToken) async {
    final response = await _dio.post('/auth/google', data: {'idToken': idToken});
    return response.data;
  }

  /// GET /auth/me
  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  // ─── Tasks ───

  /// GET /tasks
  Future<List<dynamic>> getTasks() async {
    final response = await _dio.get('/tasks');
    return response.data['items'];
  }

  /// GET /tasks/:id
  Future<Map<String, dynamic>> getTask(String id) async {
    final response = await _dio.get('/tasks/$id');
    return response.data;
  }

  /// POST /tasks
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    final response = await _dio.post('/tasks', data: body);
    return response.data;
  }

  /// PATCH /tasks/:id
  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/tasks/$id', data: body);
    return response.data;
  }

  /// DELETE /tasks/:id
  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  // ─── Priorities ───

  /// GET /priorities
  Future<List<dynamic>> getPriorities() async {
    final response = await _dio.get('/priorities');
    return response.data['items'];
  }

  /// POST /priorities
  Future<Map<String, dynamic>> createPriority(Map<String, dynamic> body) async {
    final response = await _dio.post('/priorities', data: body);
    return response.data;
  }

  /// PATCH /priorities/:id
  Future<Map<String, dynamic>> updatePriority(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/priorities/$id', data: body);
    return response.data;
  }

  /// DELETE /priorities/:id
  Future<void> deletePriority(String id) async {
    await _dio.delete('/priorities/$id');
  }

  // ─── Statuses ───

  /// GET /statuses
  Future<List<dynamic>> getStatuses() async {
    final response = await _dio.get('/statuses');
    return response.data['items'];
  }

  /// POST /statuses
  Future<Map<String, dynamic>> createStatus(Map<String, dynamic> body) async {
    final response = await _dio.post('/statuses', data: body);
    return response.data;
  }

  /// PATCH /statuses/:id
  Future<Map<String, dynamic>> updateStatus(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/statuses/$id', data: body);
    return response.data;
  }

  /// DELETE /statuses/:id
  Future<void> deleteStatus(String id) async {
    await _dio.delete('/statuses/$id');
  }

  // ─── Tags ───

  /// GET /tags
  Future<List<dynamic>> getTags() async {
    final response = await _dio.get('/tags');
    return response.data['items'];
  }

  /// POST /tags
  Future<Map<String, dynamic>> createTag(Map<String, dynamic> body) async {
    final response = await _dio.post('/tags', data: body);
    return response.data;
  }

  /// PATCH /tags/:id
  Future<Map<String, dynamic>> updateTag(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/tags/$id', data: body);
    return response.data;
  }

  /// DELETE /tags/:id
  Future<void> deleteTag(String id) async {
    await _dio.delete('/tags/$id');
  }
}
```

### `api_exception.dart`

API エラーを統一的にハンドリングするためのラッパーです。

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  factory ApiException.fromDioException(DioException e) {
    final data = e.response?.data;
    return ApiException(
      statusCode: e.response?.statusCode ?? 0,
      message: data is Map ? data['message'] ?? e.message ?? '' : e.message ?? '',
    );
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
}
```

### リポジトリ実装の書き換え

`data/repositories/` を API 呼び出しベースに全面書き換えします。

**`task_repository_impl.dart` の例:**

```dart
class TaskRepositoryImpl implements TaskRepository {
  final ApiClient _api;

  TaskRepositoryImpl(this._api);

  @override
  Future<List<Task>> getTasks({...}) async {
    final items = await _api.getTasks();
    return items.map((json) => _toTask(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<Task> getTaskById(String id) async {
    final json = await _api.getTask(id);
    return _toTask(json);
  }

  @override
  Future<Task> addTask({
    required String title,
    String? memo,
    DateTime? dueDate,
    required String statusId,
    String? priorityId,
    List<String>? tagIds,
  }) async {
    final json = await _api.createTask({
      'title': title,
      if (memo != null) 'memo': memo,
      if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      'statusId': statusId,
      if (priorityId != null) 'priorityId': priorityId,
      if (tagIds != null) 'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<Task> updateTask({
    required String id,
    String? title,
    String? memo,
    DateTime? dueDate,
    String? statusId,
    String? priorityId,
    List<String>? tagIds,
  }) async {
    final json = await _api.updateTask(id, {
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      if (statusId != null) 'statusId': statusId,
      if (priorityId != null) 'priorityId': priorityId,
      if (tagIds != null) 'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _api.deleteTask(id);
  }

  // ─── JSON → ドメインモデル変換 ───

  Task _toTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      memo: json['memo'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      // priority と status は ID のみ返却される
      // → 別途 priorityProvider / statusProvider から参照して結合する
      // （後述の「Provider でのリレーション解決」を参照）
      priority: null,
      status: null,
      tags: const [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
```

### Provider でのリレーション解決

API の Task レスポンスには `statusId`・`priorityId`・`tagIds` が含まれますが、`Status`・`Priority`・`Tag` のオブジェクト自体は含まれません。リレーションの解決は Provider 層で行います。

```dart
// task_provider.dart
final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final rawTasks = await ref.watch(taskRepositoryProvider).getTasks(...);
  final priorities = await ref.watch(priorityListProvider.future);
  final statuses = await ref.watch(statusListProvider.future);
  final tags = await ref.watch(tagListProvider.future);

  // priorityId → Priority オブジェクトに変換
  return rawTasks.map((task) {
    return task.copyWith(
      priority: priorities.where((p) => p.id == task.priorityId).firstOrNull,
      status: statuses.where((s) => s.id == task.statusId).firstOrNull,
      tags: task.tagIds.map((id) => tags.firstWhere((t) => t.id == id)).toList(),
    );
  }).toList();
});
```

> **代替案**: Task モデルに `statusId`・`priorityId`・`tagIds` フィールドを追加し、リポジトリ層では ID のみ保持、Provider 層でオブジェクトを結合する設計にもできます。

**全リポジトリの書き換え対象:**

| ファイル | 変更内容 |
|---------|---------|
| `task_repository_impl.dart` | drift クエリ → `_api.getTasks()` 等 |
| `priority_repository_impl.dart` | drift クエリ → `_api.getPriorities()` 等 |
| `status_repository_impl.dart` | drift クエリ → `_api.getStatuses()` 等 |
| `tag_repository_impl.dart` | drift クエリ → `_api.getTags()` 等 |

---

## Step 4: 認証の実装

### Google Sign-In + JWT フロー

```
1. GoogleSignIn.signIn() → Google ID Token 取得
2. POST /auth/google { idToken: "..." } → JWT 取得
3. flutter_secure_storage に JWT を保存
4. 以降の API リクエストに Authorization: Bearer <JWT> を自動付与
```

### 新規ファイル

**`presentation/providers/auth_provider.dart`:**

```dart
// 認証状態
enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? accessToken;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
}

// AuthNotifier: Google Sign-In → JWT 取得 → 状態更新
//
// google_sign_in v7 の変更点:
//   - GoogleSignIn.instance シングルトンを使用
//   - initialize() を最初に呼ぶ必要がある
//   - 認証イベントは authenticationEvents ストリームで受信
//   - authenticate() で対話的サインイン
class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // 起動時に保存済み JWT があればログイン状態を復元
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    // JWT の有効性を確認
    try {
      final api = ref.read(apiClientProvider);
      final user = await api.getMe();
      return AuthState(
        status: AuthStatus.authenticated,
        accessToken: token,
        userId: user['id'],
        email: user['email'],
        displayName: user['displayName'],
        avatarUrl: user['avatarUrl'],
      );
    } catch (_) {
      await storage.delete(key: 'access_token');
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;

    // 1. Google Sign-In（v7: authenticate() で対話的サインイン）
    await signIn.authenticate();

    // 2. authenticationEvents からユーザー情報を取得
    //    authenticate() 成功後、authenticationEvents に SignIn イベントが流れる
    //    ここでは簡略化のため、currentUser を使用
    final account = signIn.currentUser;
    if (account == null) throw Exception('Google Sign-In failed');

    // 3. ID Token 取得
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get ID token');

    // 4. POST /auth/google
    final api = ref.read(apiClientProvider);
    final response = await api.googleLogin(idToken);

    // 5. JWT 保存
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'access_token', value: response['accessToken']);

    // 6. 状態更新
    final user = response['user'] as Map<String, dynamic>;
    state = AsyncData(AuthState(
      status: AuthStatus.authenticated,
      accessToken: response['accessToken'],
      userId: user['id'],
      email: user['email'],
      displayName: user['displayName'],
      avatarUrl: user['avatarUrl'],
    ));
  }

  Future<void> signOut() async {
    GoogleSignIn.instance.signOut();
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'access_token');
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}
```

**`main.dart` での初期化（google_sign_in v7 必須）:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google_sign_in v7: initialize() を最初に呼ぶ
  await GoogleSignIn.instance.initialize(
    serverClientId: AppConstants.googleServerClientId,
  );

  runApp(const ProviderScope(child: App()));
}
```

**`presentation/pages/login/login_page.dart`:**

- Google サインインボタンを表示（`GoogleSignIn.instance.supportsAuthenticate()` で表示可否を判定）
- サインイン成功後、自動的にメイン画面に遷移

### Google Sign-In のプラットフォーム設定

| プラットフォーム | 設定 |
|----------------|------|
| Android | `android/app/google-services.json` を配置、SHA-1 を Firebase に登録 |
| iOS | `ios/Runner/GoogleService-Info.plist` を配置、URL Scheme を追加 |
| Web | Google Cloud Console で OAuth クライアント ID を作成 |

> Firebase プロジェクトの作成と Google Sign-In の有効化が前提です。

---

## Step 5: Provider 層の変更

### 削除

```
presentation/providers/database_provider.dart  ← drift 依存を削除
```

### 新規作成

**`presentation/providers/api_provider.dart`:**

```dart
// FlutterSecureStorage インスタンス
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

// ApiClient インスタンス
final apiClientProvider = Provider((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    baseUrl: AppConstants.apiBaseUrl,
    storage: storage,
  );
});

// リポジトリ Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepositoryImpl(ref.watch(apiClientProvider));
});

final priorityRepositoryProvider = Provider<PriorityRepository>((ref) {
  return PriorityRepositoryImpl(ref.watch(apiClientProvider));
});

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepositoryImpl(ref.watch(apiClientProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepositoryImpl(ref.watch(apiClientProvider));
});
```

### 既存 Provider の変更

| ファイル | 変更内容 |
|---------|---------|
| `task_provider.dart` | `int` → `String` に変更。リレーション解決ロジックを追加 |
| `filter_provider.dart` | `List<int>` → `List<String>` に変更 |
| `priority_provider.dart` | `int` → `String` に変更 |
| `status_provider.dart` | `int` → `String` に変更 |
| `tag_provider.dart` | `int` → `String` に変更、`findOrCreate` は API 側で処理 |

### app.dart の認証ガード

```dart
class App extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return MaterialApp(
      home: authState.when(
        data: (state) => switch (state.status) {
          AuthStatus.authenticated => const MainShell(),
          AuthStatus.unauthenticated => const LoginPage(),
          AuthStatus.unknown => const SplashScreen(),
        },
        loading: () => const SplashScreen(),
        error: (_, __) => const LoginPage(),
      ),
    );
  }
}
```

---

## Step 6: WebSocket リアルタイム同期

### 新規ファイル

**`data/api/websocket_client.dart`:**

```dart
class WebSocketEvent {
  final String type;  // e.g. "task.created"
  final Map<String, dynamic> data;

  WebSocketEvent({required this.type, required this.data});

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class WebSocketClient {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final _eventController = StreamController<WebSocketEvent>.broadcast();

  Stream<WebSocketEvent> get events => _eventController.stream;

  Future<void> connect(String baseUrl, String token) async {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws?token=$token'),
    );
    _reconnectAttempts = 0;

    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _eventController.add(WebSocketEvent.fromJson(json));
      },
      onDone: _reconnect,
      onError: (_) => _reconnect(),
    );
  }

  void _reconnect() {
    // 指数バックオフ: 1s → 2s → 4s → ... → 最大 30s
    final delay = min(30, pow(2, _reconnectAttempts)).toInt();
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      // token と baseUrl は再接続時に必要 → フィールドに保持する設計にする
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
```

**`presentation/providers/websocket_provider.dart`:**

```dart
// ログイン後に WebSocket 接続を確立し、イベント受信時に対象 Provider を invalidate
final websocketProvider = Provider((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState?.status != AuthStatus.authenticated) return null;

  final client = WebSocketClient();
  client.connect(AppConstants.apiBaseUrl, authState!.accessToken!);

  client.events.listen((event) {
    switch (event.type) {
      case 'task.created' || 'task.updated' || 'task.deleted':
        ref.invalidate(tasksProvider);
      case 'priority.created' || 'priority.updated' || 'priority.deleted':
        ref.invalidate(priorityNotifierProvider);
      case 'status.created' || 'status.updated' || 'status.deleted':
        ref.invalidate(statusNotifierProvider);
      case 'tag.created' || 'tag.updated' || 'tag.deleted':
        ref.invalidate(tagNotifierProvider);
    }
  });

  ref.onDispose(() => client.dispose());
  return client;
});
```

---

## Step 7: API ベース URL の設定

**`core/constants/app_constants.dart` に追加:**

```dart
class AppConstants {
  // 既存の定数はそのまま

  // API ベース URL
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',  // ローカル開発
  );
}
```

```bash
# ローカル開発
flutter run

# 本番
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

---

## 実装順序

```
Step 1: パッケージ変更           ← drift 削除・新パッケージ追加
Step 2: ドメインモデル変更       ← int → String
Step 3: データ層の差し替え       ← drift → 手書き dio クライアント
Step 4: 認証の実装               ← Google Sign-In + JWT
Step 5: Provider 層の変更        ← 認証ガード・API Provider
Step 6: WebSocket 実装           ← リアルタイム同期
Step 7: API ベース URL の設定    ← 環境ごとの切り替え
```

### 依存関係

```
Step 1 ─→ Step 2 → Step 3（パッケージ変更後にモデル・データ層を変更）
Step 3 ─→ Step 5（データ層が揃ってから Provider を接続）
Step 4 ─→ Step 5（認証がないと Provider 層が動かない）
Step 5 ─→ Step 6（Provider が揃ってから WebSocket を接続）
Step 7 は独立（いつでも追加可能）
```

### 並行作業が可能な組み合わせ

- Step 2（モデル変更）と Step 7（URL 設定）は並行可能
- Step 3（データ層）と Step 4（認証）は並行可能
- Step 6（WebSocket）は Step 5 完了後

---

## ファイル変更一覧

### 新規作成

| ファイル | 説明 |
|---------|------|
| `data/api/api_client.dart` | 手書き dio クライアント（全 16 エンドポイント） |
| `data/api/api_exception.dart` | API エラーラッパー |
| `data/api/websocket_client.dart` | WebSocket 接続管理 |
| `presentation/providers/auth_provider.dart` | Google Sign-In + JWT |
| `presentation/providers/api_provider.dart` | ApiClient・リポジトリ Provider |
| `presentation/providers/websocket_provider.dart` | WS イベント受信 |
| `presentation/pages/login/login_page.dart` | ログイン画面 |

### 削除

| ファイル | 理由 |
|---------|------|
| `data/database/app_database.dart` | drift → API に移行 |
| `data/database/app_database.g.dart` | drift 生成コード |
| `presentation/providers/database_provider.dart` | drift 依存 |

### 変更

| ファイル | 変更内容 |
|---------|---------|
| `pubspec.yaml` | パッケージ入れ替え |
| `domain/models/task.dart` | `id: int` → `String`、`memo` 追加 |
| `domain/models/priority.dart` | `id: int` → `String` |
| `domain/models/status.dart` | `id: int` → `String` |
| `domain/models/tag.dart` | `id: int` → `String` |
| `domain/repositories/task_repository.dart` | ID 型変更・引数変更 |
| `domain/repositories/priority_repository.dart` | ID 型変更 |
| `domain/repositories/status_repository.dart` | ID 型変更 |
| `domain/repositories/tag_repository.dart` | ID 型変更 |
| `data/repositories/task_repository_impl.dart` | drift → dio API 呼び出し |
| `data/repositories/priority_repository_impl.dart` | drift → dio API 呼び出し |
| `data/repositories/status_repository_impl.dart` | drift → dio API 呼び出し |
| `data/repositories/tag_repository_impl.dart` | drift → dio API 呼び出し |
| `presentation/providers/task_provider.dart` | `int` → `String`、リレーション解決追加 |
| `presentation/providers/filter_provider.dart` | `List<int>` → `List<String>` |
| `presentation/providers/priority_provider.dart` | `int` → `String` |
| `presentation/providers/status_provider.dart` | `int` → `String` |
| `presentation/providers/tag_provider.dart` | `int` → `String` |
| `app.dart` | 認証ガード追加 |
| `core/constants/app_constants.dart` | API ベース URL 追加 |
