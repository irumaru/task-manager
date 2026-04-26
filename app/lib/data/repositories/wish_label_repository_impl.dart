import '../../data/api/api_client.dart';
import '../../domain/models/wish_label.dart';
import '../../domain/repositories/wish_label_repository.dart';

class WishLabelRepositoryImpl implements WishLabelRepository {
  final ApiClient _api;

  WishLabelRepositoryImpl(this._api);

  WishLabel _toDomain(Map<String, dynamic> json) => WishLabel(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  @override
  Future<List<WishLabel>> getWishLabels() async {
    final items = await _api.getWishLabels();
    return items
        .map((json) => _toDomain(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WishLabel> addWishLabel({required String name}) async {
    final json = await _api.createWishLabel({'name': name});
    return _toDomain(json);
  }

  @override
  Future<void> updateWishLabel({required String id, required String name}) async {
    await _api.updateWishLabel(id, {'name': name});
  }

  @override
  Future<void> deleteWishLabel(String id) async {
    await _api.deleteWishLabel(id);
  }
}
