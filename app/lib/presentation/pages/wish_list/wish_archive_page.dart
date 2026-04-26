import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wish_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/label_filter_dropdown.dart';
import 'widgets/swipeable_wish_card.dart';

class WishArchivePage extends ConsumerWidget {
  const WishArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedWishesProvider);
    final selectedLabelId = ref.watch(selectedWishLabelFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('アーカイブ')),
      body: Column(
        children: [
          const LabelFilterDropdown(),
          Expanded(
            child: archivedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (wishes) {
                if (wishes.isEmpty) {
                  return EmptyState(
                    message: selectedLabelId != null
                        ? 'このラベルに一致するアーカイブはありません'
                        : '達成したやりたいことがここに残ります',
                    icon: Icons.inventory_2_outlined,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: wishes.length,
                  itemBuilder: (context, index) {
                    return SwipeableWishCard(
                      wish: wishes[index],
                      archiveMode: true,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
