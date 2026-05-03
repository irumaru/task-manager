# Google ログイン クロスプラットフォーム対応 実装計画

## 背景

現在の Google ログインは `google_sign_in` パッケージ（v7.2.0）を使用していますが、**Windows をサポートしていません**。

### 現状

```
main.dart:
  if (defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux) {
    await GoogleSignIn.instance.initialize(...);
  }

login_page.dart:
  if (GoogleSignIn.instance.supportsAuthenticate())
    FilledButton.icon(...)  // Windows では表示されない
```

→ Windows ではログインボタンが表示されず、アプリが使えない状態。

### 目標

| プラットフォーム | 現状 | 目標 |
|----------------|------|------|
| Android | ✅ google_sign_in | ✅ ブラウザ OAuth |
| iOS | ✅ google_sign_in | ✅ ブラウザ OAuth |
| macOS | ✅ google_sign_in | ✅ ブラウザ OAuth |
| Windows | ❌ 非対応 | ✅ ブラウザ OAuth |

---

## 方針: 全プラットフォーム統一のブラウザ OAuth

`google_sign_in` パッケージを **廃止** し、全プラットフォームで **システムブラウザ経由の OAuth 2.0 Authorization Code フロー** に統一します。

### メリット

- `google_sign_in` パッケージとプラットフォーム固有の設定（GoogleService-Info.plist, google-services.json 等）が不要になる
- 認証コードが 1 つになり保守しやすい
- プラットフォーム分岐が不要
- 新しいプラットフォーム（Linux 等）にも自動的に対応

### 認証フロー

```
全プラットフォーム共通:
  1. ローカル HTTP サーバーを起動（localhost:ランダムポート）
  2. システムブラウザで Google OAuth 同意画面を開く（url_launcher）
  3. ユーザーが同意 → Google が localhost にリダイレクト
  4. リダイレクトから authorization code を取得
  5. POST /auth/google/code { code, redirectUri } → バックエンドへ
  6. バックエンドが code → token 交換 → ID Token 検証 → JWT 発行
```

```
┌─────────────┐     ブラウザ起動      ┌─────────────────┐
│  Flutter App │ ──────────────────→  │  System Browser  │
│              │                      │  (Google OAuth)  │
│  localhost   │ ←── redirect ──────  │                  │
│  HTTP Server │     ?code=xxx        └─────────────────┘
└──────┬───────┘
       │ POST /auth/google/code { code, redirectUri }
       ↓
┌──────────────┐     POST google token endpoint
│   Go API     │ ──────────────────→  Google
│   Server     │ ←── id_token ──────  (token exchange)
│              │
│  Verify ID   │
│  Upsert User │
│  Issue JWT   │
└──────────────┘
```

### なぜバックエンドで code 交換するか

- Authorization Code → Token 交換には **Google OAuth クライアントシークレット** が必要
- クライアントシークレットをクライアントアプリに埋め込むのはセキュリティ上望ましくない
- バックエンドで交換することでシークレットをサーバー側に保持できる

---

## Step 1: バックエンド — Authorization Code 交換エンドポイント追加

### 1-1. API 仕様の追加（spec/main.tsp）

既存の `GoogleAuthRequest` + `googleLogin` を削除し、新エンドポイントに置き換え:

```typespec
// 削除: GoogleAuthRequest, googleLogin

model GoogleAuthCodeRequest {
  @doc("Authorization code from OAuth2 redirect")
  code: string;

  @doc("Redirect URI used in the OAuth2 flow (must match)")
  redirectUri: string;
}

// AuthOps interface に追加:
@post
@route("/google/code")
@doc("Exchange Google authorization code for a server-issued JWT")
googleLoginWithCode(@body body: GoogleAuthCodeRequest): AuthResponse | ApiError;
```

### 1-2. tsp compile → ogen 再生成

```bash
cd spec && pnpm exec -- tsp compile .
cd ../api && go generate ./...
```

### 1-3. Google OAuth code → token 交換の実装（api/internal/auth/google.go に追加）

```go
type GoogleTokenResponse struct {
    IDToken string `json:"id_token"`
}

// ExchangeGoogleCode exchanges an authorization code for Google tokens,
// then verifies the ID token and returns user info.
func ExchangeGoogleCode(ctx context.Context, code, redirectURI, clientID, clientSecret string) (*GoogleUserInfo, error) {
    // 1. POST https://oauth2.googleapis.com/token
    data := url.Values{
        "grant_type":    {"authorization_code"},
        "code":          {code},
        "redirect_uri":  {redirectURI},
        "client_id":     {clientID},
        "client_secret": {clientSecret},
    }

    req, err := http.NewRequestWithContext(ctx, http.MethodPost,
        "https://oauth2.googleapis.com/token",
        strings.NewReader(data.Encode()))
    if err != nil {
        return nil, err
    }
    req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("token exchange failed: status %d", resp.StatusCode)
    }

    var tokenResp GoogleTokenResponse
    if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
        return nil, err
    }

    // 2. ID token を既存の VerifyGoogleIDToken で検証
    return VerifyGoogleIDToken(ctx, tokenResp.IDToken)
}
```

### 1-4. ハンドラー追加（api/internal/handler/auth.go に追加）

```go
func (h *Handler) AuthOpsGoogleLoginWithCode(ctx context.Context, req *api.GoogleAuthCodeRequest) (*api.AuthResponse, error) {
    info, err := auth.ExchangeGoogleCode(ctx, req.Code, req.RedirectUri, h.cfg.GoogleClientID, h.cfg.GoogleClientSecret)
    if err != nil {
        return nil, errUnauthorized("invalid authorization code")
    }

    // 以降は既存の googleLogin と同じロジック
    user, err := h.q.UpsertUser(ctx, repository.UpsertUserParams{
        Email:       info.Email,
        DisplayName: info.Name,
        AvatarUrl:   nilPtr(info.Picture),
    })
    if err != nil {
        return nil, err
    }

    token, err := h.jwt.Issue(user.ID, user.Email)
    if err != nil {
        return nil, err
    }

    return &api.AuthResponse{
        AccessToken: token,
        User:        *toAPIUser(user),
    }, nil
}
```

### 1-5. 環境変数の追加

```
GOOGLE_CLIENT_ID=<OAuth 2.0 クライアント ID>
GOOGLE_CLIENT_SECRET=<OAuth 2.0 クライアントシークレット>
```

---

## Step 2: Flutter — google_sign_in 廃止 + ブラウザ OAuth 実装

### 2-1. パッケージ変更（pubspec.yaml）

```yaml
# 削除
dependencies:
  google_sign_in: ^7.2.0

# 追加
dependencies:
  url_launcher: ^6.3.2   # システムブラウザでの OAuth URL 起動
```

### 2-2. ブラウザ OAuth サービスの実装

```
app/lib/data/auth/
└── browser_auth_service.dart   ← 全プラットフォーム共通
```

**`browser_auth_service.dart`:**

```dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

class AuthCodeResult {
  final String code;
  final String redirectUri;

  AuthCodeResult({required this.code, required this.redirectUri});
}

class BrowserAuthService {
  final String clientId;

  BrowserAuthService({required this.clientId});

  /// システムブラウザで Google OAuth を実行し、authorization code を取得する
  Future<AuthCodeResult> signInWithGoogle() async {
    // 1. CSRF 対策: state パラメータを生成
    final state = _generateRandomString(32);

    // 2. ランダムポートでローカル HTTP サーバーを起動
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';

    // 3. Google OAuth URL を構築
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': state,
    });

    // 4. システムブラウザで開く
    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      await server.close();
      throw Exception('Could not launch browser');
    }

    // 5. リダイレクトを待ち受け（タイムアウト: 2分）
    try {
      final request = await server.first.timeout(const Duration(minutes: 2));
      final params = request.uri.queryParameters;

      // 6. state を検証
      if (params['state'] != state) {
        throw Exception('Invalid state parameter');
      }

      // 7. エラーチェック
      if (params['error'] != null) {
        throw Exception('OAuth error: ${params['error']}');
      }

      final code = params['code'];
      if (code == null) {
        throw Exception('Authorization code not received');
      }

      // 8. ブラウザに成功メッセージを返す
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
<!DOCTYPE html>
<html>
<body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;">
  <div style="text-align:center;">
    <h1>ログイン成功</h1>
    <p>このタブを閉じてアプリに戻ってください。</p>
  </div>
</body>
</html>''');
      await request.response.close();

      return AuthCodeResult(code: code, redirectUri: redirectUri);
    } finally {
      await server.close();
    }
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
```

### 2-3. 依存パッケージ追加

```yaml
# pubspec.yaml
dependencies:
  url_launcher: ^6.3.2
```

### 2-4. ApiClient にエンドポイント追加

```dart
// api_client.dart に追加

/// POST /auth/google/code
Future<Map<String, dynamic>> googleLoginWithCode(String code, String redirectUri) async {
  final response = await _dio.post('/auth/google/code', data: {
    'code': code,
    'redirectUri': redirectUri,
  });
  return response.data;
}
```

### 2-5. AppConstants の変更

```dart
class AppConstants {
  // ...

  // 削除: googleServerClientId（google_sign_in 用）は不要になる

  // 追加: Google OAuth クライアント ID（ブラウザ OAuth 用）
  static const String googleOAuthClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
  );
}
```

---

## Step 3: AuthProvider の修正

### 3-1. AuthNotifier の書き換え

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/browser_auth_service.dart';
import 'api_provider.dart';

// ... AuthStatus, AuthState は変更なし ...

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // 変更なし: 保存済み JWT で復元を試みる
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    try {
      final api = ref.read(apiClientProvider);
      final user = await api.getMe();
      return AuthState(
        status: AuthStatus.authenticated,
        accessToken: token,
        userId: user['id'] as String?,
        email: user['email'] as String?,
        displayName: user['displayName'] as String?,
        avatarUrl: user['avatarUrl'] as String?,
      );
    } catch (_) {
      await storage.delete(key: 'access_token');
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    // 1. ブラウザで Google OAuth → authorization code 取得
    final authService = ref.read(browserAuthServiceProvider);
    final result = await authService.signInWithGoogle();

    // 2. バックエンドで code → JWT 交換
    final api = ref.read(apiClientProvider);
    final response = await api.googleLoginWithCode(result.code, result.redirectUri);

    // 3. JWT 保存 → 状態更新
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'access_token', value: response['accessToken'] as String);

    final user = response['user'] as Map<String, dynamic>;
    state = AsyncData(AuthState(
      status: AuthStatus.authenticated,
      accessToken: response['accessToken'] as String,
      userId: user['id'] as String?,
      email: user['email'] as String?,
      displayName: user['displayName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
    ));
  }

  Future<void> signOut() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'access_token');
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}
```

### 3-2. Provider 定義

```dart
// presentation/providers/api_provider.dart に追加

final browserAuthServiceProvider = Provider<BrowserAuthService>((ref) {
  return BrowserAuthService(clientId: AppConstants.googleOAuthClientId);
});
```

---

## Step 4: main.dart の簡素化

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google_sign_in の初期化は不要になった
  // ブラウザ OAuth はサインイン時にオンデマンドで動作する

  runApp(const ProviderScope(child: App()));
}
```

→ `google_sign_in` の import とプラットフォーム分岐が完全に削除される。

---

## Step 5: LoginPage の簡素化

```dart
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 72),
              const SizedBox(height: 24),
              Text(
                'タスクマネージャー',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),
              if (authAsync.isLoading)
                const CircularProgressIndicator()
              else ...[
                if (authAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'サインインに失敗しました',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                // プラットフォーム分岐不要 — 常に表示
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Google でサインイン'),
                  onPressed: () => ref
                      .read(authNotifierProvider.notifier)
                      .signInWithGoogle(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

→ `GoogleSignIn.instance.supportsAuthenticate()` のチェックが不要に。全プラットフォームでボタンを表示。

---

## Step 6: Google Cloud Console の設定

### 必要な OAuth クライアント（1つだけ）

**Web アプリケーション** タイプの OAuth クライアントを使用します。

> Google OAuth のデスクトップアプリタイプはリダイレクト URI に `http://localhost` を設定できますが、
> Web アプリケーションタイプでも「承認済みリダイレクト URI」に `http://localhost` を追加すれば同様に動作します。
> モバイルアプリもブラウザ経由で OAuth を行うため、Web タイプ 1 つで全プラットフォームをカバーできます。

### 設定手順

1. Google Cloud Console → 「認証情報」→「認証情報を作成」→「OAuth クライアント ID」
2. アプリケーションの種類: **ウェブ アプリケーション**
3. 承認済みリダイレクト URI に `http://localhost` を追加
4. クライアント ID → Flutter に `--dart-define=GOOGLE_OAUTH_CLIENT_ID=...`
5. クライアントシークレット → バックエンドの環境変数 `GOOGLE_CLIENT_SECRET`

---

## 実装順序

```
Step 1: バックエンド — /auth/google/code エンドポイント追加
  ├── 1-1. spec/main.tsp に API 仕様追加
  ├── 1-2. tsp compile → ogen 再生成
  ├── 1-3. auth/google.go に ExchangeGoogleCode 実装
  └── 1-4. handler/auth.go にハンドラー追加

Step 2: Flutter — google_sign_in 廃止 + ブラウザ OAuth 実装
  ├── 2-1. pubspec.yaml: google_sign_in 削除、url_launcher + crypto 追加
  ├── 2-2. browser_auth_service.dart 新規作成
  ├── 2-3. api_client.dart にエンドポイント追加
  └── 2-4. app_constants.dart 修正

Step 3: AuthProvider 修正
  └── 3-1. google_sign_in 依存を削除、BrowserAuthService を使用

Step 4: main.dart 簡素化
  └── 4-1. google_sign_in の初期化コードを削除

Step 5: LoginPage 簡素化
  └── 5-1. プラットフォーム分岐を削除

Step 6: Google Cloud Console で OAuth クライアント設定
```

### 依存関係

```
Step 1（バックエンド）と Step 2（Flutter）は並行作業可能
Step 3 は Step 2 完了後
Step 4・5 は Step 3 完了後
Step 6 は独立（テスト時に必要）
```

---

## ファイル変更一覧

### バックエンド（追加・変更）

| ファイル | 変更内容 |
|---------|---------|
| `spec/main.tsp` | `GoogleAuthCodeRequest` モデル + `googleLoginWithCode` エンドポイント追加 |
| `api/internal/auth/google.go` | `ExchangeGoogleCode()` 関数追加 |
| `api/internal/handler/auth.go` | `AuthOpsGoogleLoginWithCode()` ハンドラー追加 |

### Flutter（新規作成）

| ファイル | 説明 |
|---------|------|
| `app/lib/data/auth/browser_auth_service.dart` | ブラウザ OAuth サービス（全プラットフォーム共通） |

### Flutter（変更）

| ファイル | 変更内容 |
|---------|---------|
| `app/pubspec.yaml` | `google_sign_in` 削除、`url_launcher` 追加 |
| `app/lib/data/api/api_client.dart` | `googleLoginWithCode()` メソッド追加 |
| `app/lib/core/constants/app_constants.dart` | `googleServerClientId` → `googleOAuthClientId` に変更 |
| `app/lib/presentation/providers/api_provider.dart` | `browserAuthServiceProvider` 追加 |
| `app/lib/presentation/providers/auth_provider.dart` | `google_sign_in` 依存削除、`BrowserAuthService` 使用 |
| `app/lib/presentation/pages/login/login_page.dart` | `google_sign_in` import 削除、プラットフォーム分岐削除 |
| `app/lib/main.dart` | `google_sign_in` 初期化コード削除 |

---

## 補足: セキュリティ考慮事項

- **State パラメータ**: CSRF 対策としてランダム生成し、コールバックで検証する
- **ローカルサーバーのポート**: ランダムポートを使用（ポート 0 でバインド）し、固定ポートの衝突を回避する
- **タイムアウト**: ユーザーが同意画面を放置した場合に備え、2 分のタイムアウトを設定する

## 補足: Web プラットフォームについて

Flutter Web では `dart:io`（`HttpServer`）が使えません。Web 向けには以下の選択肢があります:

1. **ポップアップウィンドウ + postMessage**: Google OAuth をポップアップで開き、リダイレクト先のページから `window.postMessage` でコードを受け取る
2. **リダイレクト方式**: 現在のページを Google OAuth にリダイレクトし、戻り先で code をパースする

Web 対応が必要な場合は別途設計が必要ですが、現時点ではネイティブアプリ（Windows / macOS / iOS / Android）を優先します。Web は後から追加可能です。
