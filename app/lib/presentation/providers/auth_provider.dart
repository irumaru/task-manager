import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_provider.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? accessToken;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  const AuthState({
    required this.status,
    this.accessToken,
    this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
  });
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
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

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
