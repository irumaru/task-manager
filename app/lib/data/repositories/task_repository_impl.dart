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
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      priorityId: json['priorityId'] as String?,
      statusId: json['statusId'] as String?,
      tagIds: (json['tagIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      // priority/status/tags は Provider 層で解決
      priority: null,
      status: null,
      tags: const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
    if (filter.priorityIds.isNotEmpty) {
      tasks = tasks
          .where((t) => t.priorityId != null && filter.priorityIds.contains(t.priorityId))
          .toList();
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

    // クライアントサイドソート（priority ソートは Provider 層で解決後に行う）
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
        case SortField.title:
          compare = a.title.compareTo(b.title);
        case SortField.priority:
          // priority オブジェクト未解決のため ID で代替ソート
          compare = (a.priorityId ?? '').compareTo(b.priorityId ?? '');
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
    String? priorityId,
    List<String> tagIds = const [],
  }) async {
    final json = await _api.createTask({
      'title': title,
      if (memo != null) 'memo': memo,
      if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      'statusId': statusId,
      if (priorityId != null) 'priorityId': priorityId,
      if (tagIds.isNotEmpty) 'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<Task> updateTask({
    required String id,
    String? title,
    String? memo,
    bool clearMemo = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? priorityId,
    bool clearPriority = false,
    String? statusId,
    bool clearStatus = false,
    List<String> tagIds = const [],
  }) async {
    final json = await _api.updateTask(id, {
      if (title != null) 'title': title,
      if (clearMemo) 'memo': null else if (memo != null) 'memo': memo,
      if (clearDueDate) 'dueDate': null else if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
      if (clearPriority) 'priorityId': null else if (priorityId != null) 'priorityId': priorityId,
      if (clearStatus) 'statusId': null else if (statusId != null) 'statusId': statusId,
      'tagIds': tagIds,
    });
    return _toTask(json);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _api.deleteTask(id);
  }
}
