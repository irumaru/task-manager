import '../models/tag.dart';

abstract class TagRepository {
  Future<List<Tag>> getTags();
  Future<Tag?> getTagByName(String name);
  Future<int> addTag({required String name});
  Future<void> updateTag({required int id, required String name});
  Future<void> deleteTag(int id);
}
