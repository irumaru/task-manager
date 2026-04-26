import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/priority.dart';
import 'api_provider.dart';

final prioritiesProvider = FutureProvider<List<Priority>>((ref) {
  return ref.watch(priorityRepositoryProvider).getPriorities();
});

class PriorityNotifier extends AsyncNotifier<List<Priority>> {
  @override
  Future<List<Priority>> build() {
    return ref.watch(priorityRepositoryProvider).getPriorities();
  }

  Future<void> add(String name) async {
    final currentCount = state.value?.length ?? 0;
    await ref.read(priorityRepositoryProvider).addPriority(name: name, displayOrder: currentCount);
    ref.invalidateSelf();
  }

  Future<void> edit(String id, String name) async {
    final current = state.value ?? [];
    final target = current.firstWhere((p) => p.id == id);
    await ref.read(priorityRepositoryProvider).updatePriority(
          id: id,
          name: name,
          displayOrder: target.sortOrder,
        );
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(priorityRepositoryProvider).deletePriority(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(List<String> orderedIds) async {
    final current = state.value ?? [];
    final byId = {for (final p in current) p.id: p};
    final ordered = orderedIds.map((id) => byId[id]!).toList();
    await ref.read(priorityRepositoryProvider).reorderPriorities(ordered);
    ref.invalidateSelf();
  }
}

final priorityNotifierProvider =
    AsyncNotifierProvider<PriorityNotifier, List<Priority>>(PriorityNotifier.new);
