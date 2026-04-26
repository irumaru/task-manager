import '../models/wish.dart';

abstract class WishRepository {
  Future<List<Wish>> getWishes();
  Future<Wish> addWish({
    required String title,
    String? detail,
    List<String> labelIds = const [],
  });
  // PUT semantics: caller supplies the full new state.
  // archivedAt: null = 通常状態、値あり = アーカイブ済み。
  Future<Wish> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
    required DateTime? archivedAt,
  });
  Future<void> deleteWish(String id);
}
