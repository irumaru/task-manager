import '../models/task.dart';

enum SortField { createdAt, updatedAt, dueDate, importance, urgency, title }

enum SortOrder { asc, desc }

class TaskFilter {
  final List<String> tagIds;
  final Set<int> importanceLevels;
  final Set<int> urgencyLevels;
  final List<String> statusIds;
  final List<String> excludeStatusIds;
  final bool? isOverdue;
  final String searchQuery;

  const TaskFilter({
    this.tagIds = const [],
    this.importanceLevels = const {},
    this.urgencyLevels = const {},
    this.statusIds = const [],
    this.excludeStatusIds = const [],
    this.isOverdue,
    this.searchQuery = '',
  });

  TaskFilter copyWith({
    List<String>? tagIds,
    Set<int>? importanceLevels,
    Set<int>? urgencyLevels,
    List<String>? statusIds,
    List<String>? excludeStatusIds,
    bool? isOverdue,
    String? searchQuery,
  }) {
    return TaskFilter(
      tagIds: tagIds ?? this.tagIds,
      importanceLevels: importanceLevels ?? this.importanceLevels,
      urgencyLevels: urgencyLevels ?? this.urgencyLevels,
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
    int importance,
    int urgency,
    List<String> tagIds,
  });

  Future<Task> updateTask({
    required String id,
    required String title,
    required String? memo,
    required DateTime? dueDate,
    required String statusId,
    required int importance,
    required int urgency,
    required List<String> tagIds,
  });

  Future<void> deleteTask(String id);
}
