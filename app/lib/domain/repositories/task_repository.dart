import '../models/task.dart';

enum SortField { createdAt, updatedAt, dueDate, priority, title }

enum SortOrder { asc, desc }

class TaskFilter {
  final List<String> tagIds;
  final List<String> priorityIds;
  final List<String> statusIds;
  final List<String> excludeStatusIds;
  final bool? isOverdue;
  final String searchQuery;

  const TaskFilter({
    this.tagIds = const [],
    this.priorityIds = const [],
    this.statusIds = const [],
    this.excludeStatusIds = const [],
    this.isOverdue,
    this.searchQuery = '',
  });

  TaskFilter copyWith({
    List<String>? tagIds,
    List<String>? priorityIds,
    List<String>? statusIds,
    List<String>? excludeStatusIds,
    bool? isOverdue,
    String? searchQuery,
  }) {
    return TaskFilter(
      tagIds: tagIds ?? this.tagIds,
      priorityIds: priorityIds ?? this.priorityIds,
      statusIds: statusIds ?? this.statusIds,
      excludeStatusIds: excludeStatusIds ?? this.excludeStatusIds,
      isOverdue: isOverdue ?? this.isOverdue,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

abstract class TaskRepository {
  Future<List<Task>> getTasks({
    TaskFilter filter,
    SortField sortField,
    SortOrder sortOrder,
  });

  Future<Task?> getTaskById(String id);

  Future<Task> addTask({
    required String title,
    String? memo,
    DateTime? dueDate,
    required String statusId,
    String? priorityId,
    List<String> tagIds,
  });

  Future<Task> updateTask({
    required String id,
    String? title,
    String? memo,
    bool clearMemo,
    DateTime? dueDate,
    bool clearDueDate,
    String? priorityId,
    bool clearPriority,
    String? statusId,
    bool clearStatus,
    List<String> tagIds,
  });

  Future<void> deleteTask(String id);
}
