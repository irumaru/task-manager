import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/status.dart';
import 'api_provider.dart';

final statusesProvider = FutureProvider<List<Status>>((ref) {
  return ref.watch(statusRepositoryProvider).getStatuses();
});

class StatusNotifier extends AsyncNotifier<List<Status>> {
  @override
  Future<List<Status>> build() {
    return ref.watch(statusRepositoryProvider).getStatuses();
  }

  Future<void> add(String name) async {
    final currentCount = state.value?.length ?? 0;
    await ref.read(statusRepositoryProvider).addStatus(name: name, displayOrder: currentCount);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, String name) async {
    final current = state.value ?? [];
    final target = current.firstWhere((s) => s.id == id);
    await ref.read(statusRepositoryProvider).updateStatus(
          id: id,
          name: name,
          displayOrder: target.sortOrder,
        );
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(statusRepositoryProvider).deleteStatus(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(List<String> orderedIds) async {
    final current = state.value ?? [];
    final byId = {for (final s in current) s.id: s};
    final ordered = orderedIds.map((id) => byId[id]!).toList();
    await ref.read(statusRepositoryProvider).reorderStatuses(ordered);
    ref.invalidateSelf();
  }
}

final statusNotifierProvider =
    AsyncNotifierProvider<StatusNotifier, List<Status>>(StatusNotifier.new);
