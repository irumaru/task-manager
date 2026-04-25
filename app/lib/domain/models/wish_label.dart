class WishLabel {
  final String id;
  final String name;

  const WishLabel({required this.id, required this.name});

  WishLabel copyWith({String? id, String? name}) {
    return WishLabel(id: id ?? this.id, name: name ?? this.name);
  }
}
