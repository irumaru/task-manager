import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/repositories/task_repository.dart';
import '../../../providers/filter_provider.dart';
import '../../../providers/priority_provider.dart';
import '../../../providers/status_provider.dart';
import '../../../providers/tag_provider.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(filterProvider);
    final priorities = ref.watch(priorityNotifierProvider).value ?? [];
    final statuses = ref.watch(statusNotifierProvider).value ?? [];
    final tags = ref.watch(tagNotifierProvider).value ?? [];

    final hasFilter = filterState.filter.tagIds.isNotEmpty ||
        filterState.filter.priorityIds.isNotEmpty ||
        filterState.filter.statusIds.isNotEmpty ||
        filterState.filter.isOverdue == true ||
        filterState.showCompleted;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // ソートボタン
          _SortButton(),
          const SizedBox(width: 8),
          // 完了タスク表示
          FilterChip(
            label: const Text('完了を表示'),
            selected: filterState.showCompleted,
            onSelected: (_) => ref.read(filterProvider.notifier).toggleShowCompleted(),
          ),
          const SizedBox(width: 8),
          // 期限切れ
          FilterChip(
            label: const Text('期限切れ'),
            selected: filterState.filter.isOverdue == true,
            onSelected: (v) => ref
                .read(filterProvider.notifier)
                .setIsOverdue(v ? true : null),
          ),
          const SizedBox(width: 8),
          // 優先度フィルタ
          ...priorities.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(p.name),
                  selected: filterState.filter.priorityIds.contains(p.id),
                  onSelected: (v) {
                    final ids = List<String>.from(filterState.filter.priorityIds);
                    v ? ids.add(p.id) : ids.remove(p.id);
                    ref.read(filterProvider.notifier).setPriorityIds(ids);
                  },
                ),
              )),
          // ステータスフィルタ
          ...statuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.name),
                  selected: filterState.filter.statusIds.contains(s.id),
                  onSelected: (v) {
                    final ids = List<String>.from(filterState.filter.statusIds);
                    v ? ids.add(s.id) : ids.remove(s.id);
                    ref.read(filterProvider.notifier).setStatusIds(ids);
                  },
                ),
              )),
          // タグフィルタ
          ...tags.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(t.name),
                  selected: filterState.filter.tagIds.contains(t.id),
                  onSelected: (v) {
                    final ids = List<String>.from(filterState.filter.tagIds);
                    v ? ids.add(t.id) : ids.remove(t.id);
                    ref.read(filterProvider.notifier).setTagIds(ids);
                  },
                ),
              )),
          // リセット
          if (hasFilter) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('リセット'),
              avatar: const Icon(Icons.clear, size: 16),
              onPressed: () => ref.read(filterProvider.notifier).reset(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(filterProvider);
    return PopupMenuButton<SortField>(
      child: Chip(
        avatar: Icon(
          filterState.sortOrder == SortOrder.asc
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          size: 16,
        ),
        label: Text(_sortLabel(filterState.sortField)),
      ),
      onSelected: (field) {
        final notifier = ref.read(filterProvider.notifier);
        if (field == filterState.sortField) {
          notifier.setSortOrder(filterState.sortOrder == SortOrder.asc
              ? SortOrder.desc
              : SortOrder.asc);
        } else {
          notifier.setSortField(field);
          notifier.setSortOrder(SortOrder.desc);
        }
      },
      itemBuilder: (_) => [
        for (final field in SortField.values)
          PopupMenuItem(
            value: field,
            child: Row(
              children: [
                if (filterState.sortField == field)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(_sortLabel(field)),
              ],
            ),
          ),
      ],
    );
  }

  String _sortLabel(SortField field) {
    switch (field) {
      case SortField.createdAt:
        return '作成日時';
      case SortField.updatedAt:
        return '更新日時';
      case SortField.dueDate:
        return '期限日';
      case SortField.priority:
        return '優先度';
      case SortField.title:
        return 'タイトル';
    }
  }
}
