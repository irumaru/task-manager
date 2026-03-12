import 'package:flutter/material.dart';
import '../../../../domain/models/task.dart';
import '../../../../core/utils/date_utils.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;

  const TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = AppDateUtils.isOverdue(task.dueDate);
    final isDueToday = AppDateUtils.isDueToday(task.dueDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (task.priority != null)
                    _PriorityChip(name: task.priority!.name),
                ],
              ),
              if (task.dueDate != null || task.status != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isOverdue
                            ? colorScheme.error
                            : isDueToday
                                ? colorScheme.primary
                                : colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppDateUtils.formatDate(task.dueDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? colorScheme.error
                                  : isDueToday
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                            ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (task.status != null)
                      _StatusChip(name: task.status!.name),
                  ],
                ),
              ],
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: task.tags
                      .map((tag) => Chip(
                            label: Text(tag.name),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String name;
  const _PriorityChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String name;
  const _StatusChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}
