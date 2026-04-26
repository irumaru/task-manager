class Wish {
  final String id;
  final String title;
  final String? detail;
  final List<String> labelIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Wish({
    required this.id,
    required this.title,
    this.detail,
    this.labelIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Wish copyWith({
    String? id,
    String? title,
    String? detail,
    bool clearDetail = false,
    List<String>? labelIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wish(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: clearDetail ? null : (detail ?? this.detail),
      labelIds: labelIds ?? this.labelIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
