class Wish {
  final String id;
  final String title;
  final String? detail;
  final List<String> labelIds;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  const Wish({
    required this.id,
    required this.title,
    this.detail,
    this.labelIds = const [],
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Wish copyWith({
    String? id,
    String? title,
    String? detail,
    bool clearDetail = false,
    List<String>? labelIds,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wish(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: clearDetail ? null : (detail ?? this.detail),
      labelIds: labelIds ?? this.labelIds,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
