class Tag {
  final String id;
  final String name;

  const Tag({
    required this.id,
    required this.name,
  });

  Tag copyWith({String? id, String? name}) {
    return Tag(id: id ?? this.id, name: name ?? this.name);
  }
}
