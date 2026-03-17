import '../models/tag.dart';

abstract class TagRepository {
  Future<List<Tag>> getTags();
  Future<Tag> addTag({required String name});
  Future<void> updateTag({required String id, required String name});
  Future<void> deleteTag(String id);
}
