import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/wish_label.dart';
import '../../../providers/wish_label_provider.dart';
import '../../../providers/wish_provider.dart';

class LabelFilterDropdown extends ConsumerWidget {
  const LabelFilterDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(wishLabelNotifierProvider);
    final selectedId = ref.watch(selectedWishLabelFilterProvider);

    return labelsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (labels) {
        if (labels.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DropdownButtonFormField<String?>(
            key: ValueKey(selectedId),
            initialValue: selectedId,
            decoration: const InputDecoration(
              labelText: 'ラベルで絞り込み',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('すべて')),
              ...labels.map((WishLabel l) =>
                  DropdownMenuItem(value: l.id, child: Text(l.name))),
            ],
            onChanged: (id) =>
                ref.read(selectedWishLabelFilterProvider.notifier).select(id),
          ),
        );
      },
    );
  }
}
