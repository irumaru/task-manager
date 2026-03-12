import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/priority.dart';
import 'database_provider.dart';

final prioritiesProvider = FutureProvider<List<Priority>>((ref) {
  return ref.watch(priorityRepositoryProvider).getPriorities();
});

class PriorityNotifier extends AsyncNotifier<List<Priority>> {
  @override
  Future<List<Priority>> build() {
    return ref.watch(priorityRepositoryProvider).getPriorities();
  }

  Future<void> add(String name) async {
    await ref.read(priorityRepositoryProvider).addPriority(name: name);
    ref.invalidateSelf();
  }

  Future<void> edit(int id, String name) async {
    await ref.read(priorityRepositoryProvider).updatePriority(id: id, name: name);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await ref.read(priorityRepositoryProvider).deletePriority(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(List<int> orderedIds) async {
    await ref.read(priorityRepositoryProvider).reorderPriorities(orderedIds);
    ref.invalidateSelf();
  }
}

final priorityNotifierProvider =
    AsyncNotifierProvider<PriorityNotifier, List<Priority>>(PriorityNotifier.new);
