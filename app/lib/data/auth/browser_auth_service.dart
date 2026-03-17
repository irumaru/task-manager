import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

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
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 5000);
    final redirectUri = 'http://localhost:${server.port}';

    // 3. Google OAuth URL を構築
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': state,
    });

    debugPrint('Opening browser for Google OAuth: $authUrl');

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
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }
}
