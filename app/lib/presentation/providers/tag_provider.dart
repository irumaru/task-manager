import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/tag.dart';
import 'api_provider.dart';

class TagNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() {
    return ref.watch(tagRepositoryProvider).getTags();
  }

  /// 同名タグを検索し、なければ作成して ID を返す
  Future<String> findOrCreate(String name) async {
    final tags = state.value ?? await future;
    final existing = tags.where((t) => t.name == name).firstOrNull;
    if (existing != null) return existing.id;
    final tag = await ref.read(tagRepositoryProvider).addTag(name: name);
    ref.invalidateSelf();
    return tag.id;
  }

  Future<void> edit(String id, String name) async {
    await ref.read(tagRepositoryProvider).updateTag(id: id, name: name);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(tagRepositoryProvider).deleteTag(id);
    ref.invalidateSelf();
  }
}

final tagNotifierProvider =
    AsyncNotifierProvider<TagNotifier, List<Tag>>(TagNotifier.new);

/// 直前にタスクへ付与したタグの ID（アプリ起動中のみ保持）。
/// 連続作成時のサジェスト用。
class LastUsedTagIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final lastUsedTagIdProvider =
    NotifierProvider<LastUsedTagIdNotifier, String?>(
  LastUsedTagIdNotifier.new,
);
