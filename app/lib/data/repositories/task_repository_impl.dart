import '../../data/api/api_client.dart';
import '../../domain/models/task.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final ApiClient _api;

  TaskRepositoryImpl(this._api);

  Task _toTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      memo: json['memo'] as String?,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String).toLocal() : null,
      importance: (json['importance'] as num?)?.toInt() ?? 1,
      urgency: (json['urgency'] as num?)?.toInt() ?? 1,
      statusId: json['statusId'] as String,
      tagIds: (json['tagIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      // status/tags は Provider 層で解決
      status: null,
      tags: const [],
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  @override
  Future<List<Task>> getTasks({
    TaskFilter filter = const TaskFilter(),
    SortField sortField = SortField.createdAt,
    SortOrder sortOrder = SortOrder.desc,
  }) async {
    final items = await _api.getTasks();
    var tasks = items.map((json) => _toTask(json as Map<String, dynamic>)).toList();

    // クライアントサイドフィルタリング
    if (filter.searchQuery.isNotEmpty) {
      tasks = tasks
          .where((t) => t.title.toLowerCase().contains(filter.searchQuery.toLowerCase()))
          .toList();
    }
    if (filter.importanceLevels.isNotEmpty) {
      tasks = tasks.where((t) => filter.importanceLevels.contains(t.importance)).toList();
    }
    if (filter.urgencyLevels.isNotEmpty) {
      tasks = tasks.where((t) => filter.urgencyLevels.contains(t.urgency)).toList();
    }
    if (filter.statusIds.isNotEmpty) {
      tasks = tasks
          .where((t) => t.statusId != null && filter.statusIds.contains(t.statusId))
          .toList();
    }
    if (filter.excludeStatusIds.isNotEmpty) {
      tasks = tasks
          .where((t) => !filter.excludeStatusIds.contains(t.statusId))
          .toList();
    }
    if (filter.tagIds.isNotEmpty) {
      tasks = tasks
          .where((t) => t.tagIds.any((id) => filter.tagIds.contains(id)))
          .toList();
    }
    if (filter.isOverdue == true) {
      final now = DateTime.now();
      tasks = tasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(now)).toList();
    }

    tasks.sort((a, b) {
      int compare;
      switch (sortField) {
        case SortField.createdAt:
          compare = a.createdAt.compareTo(b.createdAt);
        case SortField.updatedAt:
          compare = a.updatedAt.compareTo(b.updatedAt);
        case SortField.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            compare = 0;
          } else if (a.dueDate == null) {
            compare = 1;
          } else if (b.dueDate == null) {
            compare = -1;
          } else {
            compare = a.dueDate!.compareTo(b.dueDate!);
          }
        case SortField.importance:
          compare = a.importance.compareTo(b.importance);
        case SortField.urgency:
          compare = a.urgency.compareTo(b.urgency);
        case SortField.title:
          compare = a.title.compareTo(b.title);
      }
      return sortOrder == SortOrder.asc ? compare : -compare;
    });

    return tasks;
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final json = await _api.getTask(id);
    return _toTask(json);
  }

  @override
  Future<Task> addTask({
    required String title,
    String? memo,
    DateTime? dueDate,
    required String statusId,
    int importance = 1,
    int urgency = 1,
    List<String> tagIds = const [],
  }) async {
    final json = await _api.createTask({
      'title': title,
      'memo': ?memo,
      'dueDate': ?dueDate?.toUtc().toIso8601String(),
      'statusId': statusId,
      'importance': importance,
      'urgency': urgency,
      if (tagIds.isNotEmpty) 'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<Task> updateTask({
    required String id,
    required String title,
    required String? memo,
    required DateTime? dueDate,
    required String statusId,
    required int importance,
    required int urgency,
    required List<String> tagIds,
  }) async {
    final json = await _api.updateTask(id, {
      'title': title,
      'memo': memo,
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'statusId': statusId,
      'importance': importance,
      'urgency': urgency,
      'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _api.deleteTask(id);
  }
}
