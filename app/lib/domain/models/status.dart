class Status {
  final int id;
  final String name;
  final int sortOrder;
  final bool isDefault;

  const Status({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isDefault,
  });

  Status copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isDefault,
  }) {
    return Status(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
