import '../../data/api/api_client.dart';
import '../../domain/models/wish.dart';
import '../../domain/repositories/wish_repository.dart';

class WishRepositoryImpl implements WishRepository {
  final ApiClient _api;

  WishRepositoryImpl(this._api);

  Wish _toDomain(Map<String, dynamic> json) => Wish(
        id: json['id'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String?,
        labelIds: (json['labelIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        archivedAt: json['archivedAt'] != null
            ? DateTime.parse(json['archivedAt'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );

  @override
  Future<List<Wish>> getWishes({bool includeArchived = false}) async {
    final items = await _api.getWishes(includeArchived: includeArchived);
    return items.map((json) => _toDomain(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<Wish> addWish({
    required String title,
    String? detail,
    List<String> labelIds = const [],
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'detail': ?detail,
      'labelIds': labelIds,
    };
    final json = await _api.createWish(body);
    return _toDomain(json);
  }

  @override
  Future<Wish> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'detail': detail,
      'labelIds': labelIds,
    };
    final json = await _api.updateWish(id, body);
    return _toDomain(json);
  }

  @override
  Future<void> deleteWish(String id) async {
    await _api.deleteWish(id);
  }

  @override
  Future<Wish> archiveWish(String id) async {
    final json = await _api.archiveWish(id);
    return _toDomain(json);
  }

  @override
  Future<Wish> unarchiveWish(String id) async {
    final json = await _api.unarchiveWish(id);
    return _toDomain(json);
  }
}
