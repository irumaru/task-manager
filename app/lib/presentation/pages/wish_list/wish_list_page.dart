import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/wish_provider.dart';
import '../wish_form/wish_form_page.dart';
import '../../widgets/empty_state.dart';
import 'widgets/label_filter_dropdown.dart';
import 'widgets/wish_card.dart';

class WishListPage extends ConsumerWidget {
  const WishListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredWishesProvider);
    final selectedLabelId = ref.watch(selectedWishLabelFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('やりたいこと'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final showArchived = ref.watch(showArchivedProvider);
              return IconButton(
                icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
                tooltip: showArchived ? 'アーカイブを隠す' : 'アーカイブを表示',
                onPressed: () =>
                    ref.read(showArchivedProvider.notifier).toggle(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const LabelFilterDropdown(),
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
              data: (wishes) {
                if (wishes.isEmpty) {
                  return EmptyState(
                    message: selectedLabelId != null
                        ? 'このラベルに一致するやりたいことはありません'
                        : 'やりたいことを追加しましょう',
                    icon: Icons.lightbulb_outline,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: wishes.length,
                  itemBuilder: (context, index) {
                    final wish = wishes[index];
                    return WishCard(
                      wish: wish,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WishFormPage(wish: wish),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WishFormPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
