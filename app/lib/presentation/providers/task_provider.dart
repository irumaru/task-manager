import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/task.dart';
import 'database_provider.dart';
import 'filter_provider.dart';
import 'status_provider.dart';

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  final filterState = ref.watch(filterProvider);
  final statuses = await ref.watch(statusNotifierProvider.future);

  // 完了ステータスのIDを取得して除外リストを構築
  List<int> excludeStatusIds = [];
  if (!filterState.showCompleted && filterState.filter.statusIds.isEmpty) {
    excludeStatusIds = statuses
        .where((s) => s.name == '完了')
        .map((s) => s.id)
        .toList();
  }

  final filter = filterState.filter.copyWith(
    excludeStatusIds: excludeStatusIds,
  );

  return repo.getTasks(
    filter: filter,
    sortField: filterState.sortField,
    sortOrder: filterState.sortOrder,
  );
});

class TaskNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addTask({
    required String title,
    DateTime? dueDate,
    int? priorityId,
    int? statusId,
    List<int> tagIds = const [],
  }) async {
    await ref.read(taskRepositoryProvider).addTask(
          title: title,
          dueDate: dueDate,
          priorityId: priorityId,
          statusId: statusId,
          tagIds: tagIds,
        );
    ref.invalidate(tasksProvider);
  }

  Future<void> updateTask({
    required int id,
    required String title,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? priorityId,
    bool clearPriority = false,
    int? statusId,
    bool clearStatus = false,
    List<int> tagIds = const [],
  }) async {
    await ref.read(taskRepositoryProvider).updateTask(
          id: id,
          title: title,
          dueDate: dueDate,
          clearDueDate: clearDueDate,
          priorityId: priorityId,
          clearPriority: clearPriority,
          statusId: statusId,
          clearStatus: clearStatus,
          tagIds: tagIds,
        );
    ref.invalidate(tasksProvider);
  }

  Future<void> deleteTask(int id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    ref.invalidate(tasksProvider);
  }
}

final taskNotifierProvider =
    AsyncNotifierProvider<TaskNotifier, void>(TaskNotifier.new);
