import '../models/wish_label.dart';

abstract class WishLabelRepository {
  Future<List<WishLabel>> getWishLabels();
  Future<WishLabel> addWishLabel({required String name});
  Future<void> updateWishLabel({required String id, required String name});
  Future<void> deleteWishLabel(String id);
}
