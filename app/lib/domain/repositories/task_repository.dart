import '../models/task.dart';

enum SortField { createdAt, updatedAt, dueDate, priority, title }

enum SortOrder { asc, desc }

class TaskFilter {
  final List<int> tagIds;
  final List<int> priorityIds;
  final List<int> statusIds;
  final List<int> excludeStatusIds;
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
    List<int>? tagIds,
    List<int>? priorityIds,
    List<int>? statusIds,
    List<int>? excludeStatusIds,
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

  Future<Task?> getTaskById(int id);

  Future<int> addTask({
    required String title,
    DateTime? dueDate,
    int? priorityId,
    int? statusId,
    List<int> tagIds,
  });

  Future<void> updateTask({
    required int id,
    required String title,
    DateTime? dueDate,
    bool clearDueDate,
    int? priorityId,
    bool clearPriority,
    int? statusId,
    bool clearStatus,
    List<int> tagIds,
  });

  Future<void> deleteTask(int id);
}
