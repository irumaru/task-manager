import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../domain/models/task.dart';
import '../../domain/models/priority.dart';
import '../../domain/models/status.dart';
import '../../domain/models/tag.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final AppDatabase _db;

  TaskRepositoryImpl(this._db);

  Future<List<Tag>> _getTagsForTask(int taskId) async {
    final rows = await (_db.select(_db.taskTags)
          ..where((t) => t.taskId.equals(taskId)))
        .get();
    if (rows.isEmpty) return [];
    final tagIds = rows.map((r) => r.tagId).toList();
    final tags = await (_db.select(_db.tags)
          ..where((t) => t.id.isIn(tagIds)))
        .get();
    return tags.map((t) => Tag(id: t.id, name: t.name)).toList();
  }

  Future<Task> _toTask(TaskData d) async {
    Priority? priority;
    if (d.priorityId != null) {
      final p = await (_db.select(_db.priorities)
            ..where((t) => t.id.equals(d.priorityId!)))
          .getSingleOrNull();
      if (p != null) {
        priority = Priority(
            id: p.id, name: p.name, sortOrder: p.sortOrder, isDefault: p.isDefault);
      }
    }

    Status? status;
    if (d.statusId != null) {
      final s = await (_db.select(_db.statuses)
            ..where((t) => t.id.equals(d.statusId!)))
          .getSingleOrNull();
      if (s != null) {
        status = Status(
            id: s.id, name: s.name, sortOrder: s.sortOrder, isDefault: s.isDefault);
      }
    }

    final tags = await _getTagsForTask(d.id);

    return Task(
      id: d.id,
      title: d.title,
      dueDate: d.dueDate,
      priority: priority,
      status: status,
      tags: tags,
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
    );
  }

  @override
  Future<List<Task>> getTasks({
    TaskFilter filter = const TaskFilter(),
    SortField sortField = SortField.createdAt,
    SortOrder sortOrder = SortOrder.desc,
  }) async {
    var query = _db.select(_db.tasks);

    query.where((t) {
      Expression<bool> condition = const Constant(true);

      if (filter.searchQuery.isNotEmpty) {
        condition = condition & t.title.contains(filter.searchQuery);
      }
      if (filter.priorityIds.isNotEmpty) {
        condition = condition & t.priorityId.isIn(filter.priorityIds);
      }
      if (filter.statusIds.isNotEmpty) {
        condition = condition & t.statusId.isIn(filter.statusIds);
      }
      if (filter.excludeStatusIds.isNotEmpty) {
        condition = condition & t.statusId.isNotIn(filter.excludeStatusIds);
      }
      if (filter.isOverdue == true) {
        condition = condition &
            t.dueDate.isSmallerThan(Variable<DateTime>(DateTime.now()));
      }

      return condition;
    });

    query.orderBy([
      (t) {
        final Expression term;
        switch (sortField) {
          case SortField.createdAt:
            term = t.createdAt;
            break;
          case SortField.updatedAt:
            term = t.updatedAt;
            break;
          case SortField.dueDate:
            term = t.dueDate;
            break;
          case SortField.priority:
            term = t.priorityId;
            break;
          case SortField.title:
            term = t.title;
            break;
        }
        return OrderingTerm(
          expression: term,
          mode: sortOrder == SortOrder.asc ? OrderingMode.asc : OrderingMode.desc,
        );
      }
    ]);

    final rows = await query.get();
    final tasks = await Future.wait(rows.map(_toTask));

    if (filter.tagIds.isNotEmpty) {
      return tasks.where((task) {
        return task.tags.any((tag) => filter.tagIds.contains(tag.id));
      }).toList();
    }

    return tasks;
  }

  @override
  Future<Task?> getTaskById(int id) async {
    final row = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  @override
  Future<int> addTask({
    required String title,
    DateTime? dueDate,
    int? priorityId,
    int? statusId,
    List<int> tagIds = const [],
  }) async {
    final now = DateTime.now();
    final taskId = await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            title: title,
            dueDate: Value(dueDate),
            priorityId: Value(priorityId),
            statusId: Value(statusId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _setTaskTags(taskId, tagIds);
    return taskId;
  }

  @override
  Future<void> updateTask({
    required int id,
    required String title,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? priorityId,
    bool clearPriority = false,
    int? statusId,
    bool clearStatus = false,
    List<int> tagIds = const [],
  }) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(title),
        dueDate: clearDueDate
            ? const Value(null)
            : dueDate != null
                ? Value(dueDate)
                : const Value.absent(),
        priorityId: clearPriority
            ? const Value(null)
            : priorityId != null
                ? Value(priorityId)
                : const Value.absent(),
        statusId: clearStatus
            ? const Value(null)
            : statusId != null
                ? Value(statusId)
                : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _setTaskTags(id, tagIds);
  }

  @override
  Future<void> deleteTask(int id) async {
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(id))).go();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _setTaskTags(int taskId, List<int> tagIds) async {
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(taskId)))
        .go();
    for (final tagId in tagIds) {
      await _db.into(_db.taskTags).insertOnConflictUpdate(
            TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
          );
    }
  }
}
