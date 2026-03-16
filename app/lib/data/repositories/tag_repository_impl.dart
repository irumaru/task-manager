import '../../data/api/api_client.dart';
import '../../domain/models/tag.dart';
import '../../domain/repositories/tag_repository.dart';

class TagRepositoryImpl implements TagRepository {
  final ApiClient _api;

  TagRepositoryImpl(this._api);

  Tag _toDomain(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  @override
  Future<List<Tag>> getTags() async {
    final items = await _api.getTags();
    final list = items.map((json) => _toDomain(json as Map<String, dynamic>)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<Tag> addTag({required String name}) async {
    final json = await _api.createTag({'name': name});
    return _toDomain(json);
  }

  @override
  Future<void> updateTag({required String id, required String name}) async {
    await _api.updateTag(id, {'name': name});
  }

  @override
  Future<void> deleteTag(String id) async {
    await _api.deleteTag(id);
  }
}
