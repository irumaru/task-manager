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
    await ref.read(priorityRepositoryProvider).updatePriority(id: id, name: name);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(priorityRepositoryProvider).deletePriority(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await ref.read(priorityRepositoryProvider).reorderPriorities(orderedIds);
    ref.invalidateSelf();
  }
}

final priorityNotifierProvider =
    AsyncNotifierProvider<PriorityNotifier, List<Priority>>(PriorityNotifier.new);
