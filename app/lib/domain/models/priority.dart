class Priority {
  final int id;
  final String name;
  final int sortOrder;
  final bool isDefault;

  const Priority({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isDefault,
  });

  Priority copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isDefault,
  }) {
    return Priority(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
