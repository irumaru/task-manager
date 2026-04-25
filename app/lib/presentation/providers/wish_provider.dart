import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/wish.dart';
import 'api_provider.dart';

class SelectedWishLabelFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? labelId) => state = labelId;
}

final selectedWishLabelFilterProvider =
    NotifierProvider<SelectedWishLabelFilterNotifier, String?>(
        SelectedWishLabelFilterNotifier.new);

final wishesProvider = FutureProvider<List<Wish>>((ref) {
  return ref.watch(wishRepositoryProvider).getWishes();
});

final filteredWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    if (labelId == null) return list;
    return list.where((w) => w.labelIds.contains(labelId)).toList();
  });
});

class WishNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addWish({
    required String title,
    String? detail,
    List<String> labelIds = const [],
  }) async {
    await ref.read(wishRepositoryProvider).addWish(
          title: title,
          detail: detail,
          labelIds: labelIds,
        );
    ref.invalidate(wishesProvider);
  }

  Future<void> updateWish({
    required String id,
    required String title,
    required String? detail,
    required List<String> labelIds,
  }) async {
    await ref.read(wishRepositoryProvider).updateWish(
          id: id,
          title: title,
          detail: detail,
          labelIds: labelIds,
        );
    ref.invalidate(wishesProvider);
  }

  Future<void> deleteWish(String id) async {
    await ref.read(wishRepositoryProvider).deleteWish(id);
    ref.invalidate(wishesProvider);
  }
}

final wishNotifierProvider =
    AsyncNotifierProvider<WishNotifier, void>(WishNotifier.new);
