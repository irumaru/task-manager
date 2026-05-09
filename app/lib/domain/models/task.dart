import 'status.dart';
import 'tag.dart';

class Task {
  final String id;
  final String title;
  final String? memo;
  final DateTime? dueDate;
  final int importance;
  final int urgency;
  final String? statusId;
  final List<String> tagIds;
  // Provider 層で解決されたオブジェクト
  final Status? status;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.memo,
    this.dueDate,
    this.importance = 1,
    this.urgency = 1,
    this.statusId,
    this.tagIds = const [],
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
    int? importance,
    int? urgency,
    String? statusId,
    bool clearStatusId = false,
    List<String>? tagIds,
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
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      statusId: clearStatusId ? null : (statusId ?? this.statusId),
      tagIds: tagIds ?? this.tagIds,
      status: clearStatus ? null : (status ?? this.status),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
