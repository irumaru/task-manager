import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/wish.dart';
import '../../../../domain/models/wish_label.dart';
import '../../../providers/wish_label_provider.dart';

class WishCard extends ConsumerWidget {
  final Wish wish;
  final VoidCallback onTap;

  const WishCard({super.key, required this.wish, required this.onTap});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}日前';
    if (diff.inHours >= 1) return '${diff.inHours}時間前';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}分前';
    return 'たった今';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLabels = ref.watch(wishLabelNotifierProvider).value ?? [];
    final chipLabels = allLabels
        .where((WishLabel l) => wish.labelIds.contains(l.id))
        .toList();

    final isArchived = wish.isArchived;
    return Opacity(
      opacity: isArchived ? 0.55 : 1.0,
      child: Card(
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
                  if (isArchived) ...[
                    const Icon(Icons.archive_outlined, size: 16),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      wish.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (wish.detail != null && wish.detail!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  wish.detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (chipLabels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: chipLabels
                      .map((l) => Chip(
                            label: Text(l.name),
                            padding: EdgeInsets.zero,
                            labelStyle:
                                Theme.of(context).textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _relativeTime(wish.updatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
