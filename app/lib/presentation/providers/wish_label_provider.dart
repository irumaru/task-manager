import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/wish_label.dart';
import 'api_provider.dart';
import 'wish_provider.dart';

class WishLabelNotifier extends AsyncNotifier<List<WishLabel>> {
  @override
  Future<List<WishLabel>> build() {
    return ref.watch(wishLabelRepositoryProvider).getWishLabels();
  }

  Future<String> findOrCreate(String name) async {
    final labels = state.value ?? await future;
    final existing = labels.where((l) => l.name == name).firstOrNull;
    if (existing != null) return existing.id;
    final label =
        await ref.read(wishLabelRepositoryProvider).addWishLabel(name: name);
    ref.invalidateSelf();
    return label.id;
  }

  Future<void> edit(String id, String name) async {
    await ref
        .read(wishLabelRepositoryProvider)
        .updateWishLabel(id: id, name: name);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(wishLabelRepositoryProvider).deleteWishLabel(id);
    ref.invalidateSelf();
    if (ref.read(selectedWishLabelFilterProvider) == id) {
      ref.read(selectedWishLabelFilterProvider.notifier).select(null);
    }
  }
}

final wishLabelNotifierProvider =
    AsyncNotifierProvider<WishLabelNotifier, List<WishLabel>>(
        WishLabelNotifier.new);
