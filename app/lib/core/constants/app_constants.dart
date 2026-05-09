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

  // 重要度・緊急度の表示ラベル（1=低 / 2=中 / 3=高）
  static const Map<int, String> importanceLabels = {1: '低', 2: '中', 3: '高'};
  static const Map<int, String> urgencyLabels = {1: '低', 2: '中', 3: '高'};
  static const Map<int, String> levelLabels = {1: '低', 2: '中', 3: '高'};

  // デフォルトステータス
  static const List<Map<String, dynamic>> defaultStatuses = [
    {'name': '未着手', 'sortOrder': 0},
    {'name': '進行中', 'sortOrder': 1},
    {'name': '完了', 'sortOrder': 2},
  ];
}
