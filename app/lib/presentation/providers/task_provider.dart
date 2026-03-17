import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/task.dart';
import 'api_provider.dart';
import 'filter_provider.dart';
import 'priority_provider.dart';
import 'status_provider.dart';
import 'tag_provider.dart';

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  final filterState = ref.watch(filterProvider);
  final priorities = await ref.watch(priorityNotifierProvider.future);
  final statuses = await ref.watch(statusNotifierProvider.future);
  final tags = await ref.watch(tagNotifierProvider.future);

  // 完了ステータスのIDを取得して除外リストを構築
  List<String> excludeStatusIds = [];
  if (!filterState.showCompleted && filterState.filter.statusIds.isEmpty) {
    excludeStatusIds = statuses
        .where((s) => s.name == '完了')
        .map((s) => s.id)
        .toList();
  }

  final filter = filterState.filter.copyWith(
    excludeStatusIds: excludeStatusIds,
  );

  final rawTasks = await repo.getTasks(
    filter: filter,
    sortField: filterState.sortField,
    sortOrder: filterState.sortOrder,
  );

  // Provider 層でリレーション解決
  final priorityMap = {for (final p in priorities) p.id: p};
  final statusMap = {for (final s in statuses) s.id: s};
  final tagMap = {for (final t in tags) t.id: t};

  return rawTasks.map((task) {
    return task.copyWith(
      priority: task.priorityId != null ? priorityMap[task.priorityId] : null,
      clearPriority: task.priorityId == null,
      status: task.statusId != null ? statusMap[task.statusId] : null,
      clearStatus: task.statusId == null,
      tags: task.tagIds
          .map((id) => tagMap[id])
          .whereType<Tag>()
          .toList(),
    );
  }).toList();
});

class TaskNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addTask({
    required String title,
    String? memo,
    DateTime? dueDate,
    required String statusId,
    String? priorityId,
    List<String> tagIds = const [],
  }) async {
    await ref.read(taskRepositoryProvider).addTask(
          title: title,
          memo: memo,
          dueDate: dueDate,
          statusId: statusId,
          priorityId: priorityId,
          tagIds: tagIds,
        );
    ref.invalidate(tasksProvider);
  }

  Future<void> updateTask({
    required String id,
    String? title,
    String? memo,
    bool clearMemo = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? priorityId,
    bool clearPriority = false,
    String? statusId,
    bool clearStatus = false,
    List<String> tagIds = const [],
  }) async {
    await ref.read(taskRepositoryProvider).updateTask(
          id: id,
          title: title,
          memo: memo,
          clearMemo: clearMemo,
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

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    ref.invalidate(tasksProvider);
  }
}

final taskNotifierProvider =
    AsyncNotifierProvider<TaskNotifier, void>(TaskNotifier.new);
