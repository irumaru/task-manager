import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/tag.dart';
import 'database_provider.dart';

class TagNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() {
    return ref.watch(tagRepositoryProvider).getTags();
  }

  Future<int> findOrCreate(String name) async {
    final repo = ref.read(tagRepositoryProvider);
    final existing = await repo.getTagByName(name);
    if (existing != null) return existing.id;
    final id = await repo.addTag(name: name);
    ref.invalidateSelf();
    return id;
  }

  Future<void> edit(int id, String name) async {
    await ref.read(tagRepositoryProvider).updateTag(id: id, name: name);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await ref.read(tagRepositoryProvider).deleteTag(id);
    ref.invalidateSelf();
  }
}

final tagNotifierProvider =
    AsyncNotifierProvider<TagNotifier, List<Tag>>(TagNotifier.new);
