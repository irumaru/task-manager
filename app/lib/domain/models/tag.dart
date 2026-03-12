class Tag {
  final int id;
  final String name;

  const Tag({
    required this.id,
    required this.name,
  });

  Tag copyWith({int? id, String? name}) {
    return Tag(id: id ?? this.id, name: name ?? this.name);
  }
}
