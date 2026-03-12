class AppConstants {
  static const String appName = 'タスクマネージャー';

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
