import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

    final signIn = GoogleSignIn.instance;

    // v7: authenticate() の前にイベントを待ち受け
    final eventFuture = signIn.authenticationEvents
        .where((e) => e is GoogleSignInAuthenticationEventSignIn)
        .map((e) => e as GoogleSignInAuthenticationEventSignIn)
        .first;

    await signIn.authenticate();
    final event = await eventFuture;
    final account = event.user;
    final googleAuth = account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get ID token');

    final api = ref.read(apiClientProvider);
    final response = await api.googleLogin(idToken);

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
    await GoogleSignIn.instance.signOut();
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'access_token');
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
