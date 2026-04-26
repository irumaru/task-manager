import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/wish.dart';
import '../../../providers/wish_provider.dart';
import '../../wish_form/wish_form_page.dart';
import 'wish_card.dart';

class SwipeableWishCard extends ConsumerWidget {
  final Wish wish;
  final bool archiveMode;

  const SwipeableWishCard({
    super.key,
    required this.wish,
    required this.archiveMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(wish.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: archiveMode
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary,
        child: Icon(
          archiveMode ? Icons.unarchive_outlined : Icons.archive_outlined,
          color: Colors.white,
        ),
      ),
      // confirmDismiss でリポジトリ更新＋再取得を await することで、
      // Dismissible が自身を取り除くタイミングには既にリストから外れている。
      // onDismissed に async 処理を置くとリスト更新が間に合わず、
      // dismissed されたウィジェットがツリーに残る不整合が発生する。
      confirmDismiss: (_) async {
        final notifier = ref.read(wishNotifierProvider.notifier);
        try {
          if (archiveMode) {
            await notifier.restoreWish(wish);
          } else {
            await notifier.archiveWish(wish);
          }
        } catch (_) {
          return false;
        }
        if (context.mounted) {
          final controller = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(archiveMode ? '通常に戻しました' : 'アーカイブしました'),
              action: SnackBarAction(
                label: '元に戻す',
                onPressed: () => archiveMode
                    ? notifier.archiveWish(wish)
                    : notifier.restoreWish(wish),
              ),
            ),
          );
          // accessibleNavigation 有効時、action 付き SnackBar は自動で閉じないので
          // 明示的にタイマーで close する。
          Future.delayed(const Duration(seconds: 4), controller.close);
        }
        return true;
      },
      child: WishCard(
        wish: wish,
        archiveMode: archiveMode,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WishFormPage(wish: wish)),
        ),
      ),
    );
  }
}
