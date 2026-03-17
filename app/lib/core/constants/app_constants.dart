class AppConstants {
  static const String appName = 'タスクマネージャー';

  // API ベース URL（--dart-define=API_BASE_URL=https://... で上書き可能）
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Google OAuth クライアント ID（ブラウザ OAuth 用）
  static const String googleOAuthClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
  );

  // デフォルト優先度
  static const List<Map<String, dynamic>> defaultPriorities = [
    {'name': '絶対やる', 'sortOrder': 0},
    {'name': '余裕があったらやる', 'sortOrder': 1},
  ];

  // デフォルトステータス
  static const List<Map<String, dynamic>> defaultStatuses = [
    {'name': '未着手', 'sortOrder': 0},
    {'name': '進行中', 'sortOrder': 1},
    {'name': '完了', 'sortOrder': 2},
  ];
}
