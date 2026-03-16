import 'priority.dart';
import 'status.dart';
import 'tag.dart';

class Task {
  final String id;
  final String title;
  final String? memo;
  final DateTime? dueDate;
  // API レスポンスから取得する ID（Provider 層でオブジェクトに解決される）
  final String? priorityId;
  final String? statusId;
  final List<String> tagIds;
  // Provider 層で解決されたオブジェクト
  final Priority? priority;
  final Status? status;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.memo,
    this.dueDate,
    this.priorityId,
    this.statusId,
    this.tagIds = const [],
    this.priority,
    this.status,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? memo,
    bool clearMemo = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? priorityId,
    bool clearPriorityId = false,
    String? statusId,
    bool clearStatusId = false,
    List<String>? tagIds,
    Priority? priority,
    bool clearPriority = false,
    Status? status,
    bool clearStatus = false,
    List<Tag>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: clearMemo ? null : (memo ?? this.memo),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priorityId: clearPriorityId ? null : (priorityId ?? this.priorityId),
      statusId: clearStatusId ? null : (statusId ?? this.statusId),
      tagIds: tagIds ?? this.tagIds,
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
