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

final activeWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    final active = list.where((w) => !w.isArchived);
    final filtered = labelId == null
        ? active
        : active.where((w) => w.labelIds.contains(labelId));
    return filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

final archivedWishesProvider = Provider<AsyncValue<List<Wish>>>((ref) {
  final wishes = ref.watch(wishesProvider);
  final labelId = ref.watch(selectedWishLabelFilterProvider);
  return wishes.whenData((list) {
    final archived = list.where((w) => w.isArchived);
    final filtered = labelId == null
        ? archived
        : archived.where((w) => w.labelIds.contains(labelId));
    return filtered.toList()
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
  });
});

// 後方互換のためそのまま残す（既存の呼び出し箇所があれば移行後に削除）
final filteredWishesProvider = activeWishesProvider;

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
    required DateTime? archivedAt,
  }) async {
    await ref.read(wishRepositoryProvider).updateWish(
          id: id,
          title: title,
          detail: detail,
          labelIds: labelIds,
          archivedAt: archivedAt,
        );
    ref.invalidate(wishesProvider);
  }

  Future<void> deleteWish(String id) async {
    await ref.read(wishRepositoryProvider).deleteWish(id);
    ref.invalidate(wishesProvider);
  }

  Future<void> archiveWish(Wish target) async {
    await ref.read(wishRepositoryProvider).updateWish(
          id: target.id,
          title: target.title,
          detail: target.detail,
          labelIds: target.labelIds,
          archivedAt: DateTime.now().toUtc(),
        );
    // Dismissible が自身を取り除く前にリストを最新化する必要があるため、
    // invalidate 後に .future を await して再取得を待つ。
    ref.invalidate(wishesProvider);
    await ref.read(wishesProvider.future);
  }

  Future<void> restoreWish(Wish target) async {
    await ref.read(wishRepositoryProvider).updateWish(
          id: target.id,
          title: target.title,
          detail: target.detail,
          labelIds: target.labelIds,
          archivedAt: null,
        );
    ref.invalidate(wishesProvider);
    await ref.read(wishesProvider.future);
  }
}

final wishNotifierProvider =
    AsyncNotifierProvider<WishNotifier, void>(WishNotifier.new);
