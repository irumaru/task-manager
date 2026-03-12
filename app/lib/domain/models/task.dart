import 'priority.dart';
import 'status.dart';
import 'tag.dart';

class Task {
  final int id;
  final String title;
  final DateTime? dueDate;
  final Priority? priority;
  final Status? status;
  final List<Tag> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    this.dueDate,
    this.priority,
    this.status,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    int? id,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
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
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
