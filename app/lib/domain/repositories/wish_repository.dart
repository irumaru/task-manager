import '../models/wish.dart';

abstract class WishRepository {
  Future<List<Wish>> getWishes();
  Future<Wish> addWish({
    required String title,
    String? detail,
    List<String> labelIds = const [],
  });
  Future<Wish> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
  });
  Future<void> deleteWish(String id);
}
