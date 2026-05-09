import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/status.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/wish_label.dart';
import '../../providers/auth_provider.dart';
import '../../providers/status_provider.dart';
import '../../providers/tag_provider.dart';
import '../../providers/wish_label_provider.dart';
import '../../widgets/confirm_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: const [
          _SectionHeader('ステータス'),
          _StatusSettings(),
          _SectionHeader('タグ'),
          _TagSettings(),
          _SectionHeader('ラベル（やりたいこと）'),
          _WishLabelSettings(),
          _SectionHeader('アカウント'),
          _AccountSettings(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

// ==================== ステータス ====================

class _StatusSettings extends ConsumerWidget {
  const _StatusSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statusNotifierProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('エラー: $e'),
      data: (list) => Column(
        children: [
          ...list.map((s) => _StatusTile(status: s)),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('ステータスを追加'),
            onTap: () => _showAddDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ステータスを追加'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '名前', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(statusNotifierProvider.notifier).add(name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends ConsumerWidget {
  final Status status;
  const _StatusTile({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(status.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: status.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ステータスを編集'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '名前', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(statusNotifierProvider.notifier)
                  .edit(status.id, name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context,
        title: 'ステータスを削除',
        content:
            '「${status.name}」を削除しますか？\nこのステータスを持つタスクのステータスは空になります。');
    if (!ok) return;
    await ref.read(statusNotifierProvider.notifier).delete(status.id);
  }
}

// ==================== タグ ====================

class _TagSettings extends ConsumerWidget {
  const _TagSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tagNotifierProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('エラー: $e'),
      data: (list) => Column(
        children: list.map((t) => _TagTile(tag: t)).toList(),
      ),
    );
  }
}

class _TagTile extends ConsumerWidget {
  final Tag tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(tag.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: tag.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('タグを編集'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '名前', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(tagNotifierProvider.notifier).edit(tag.id, name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context,
        title: 'タグを削除',
        content: '「${tag.name}」を削除しますか？\nすべてのタスクからもこのタグが削除されます。');
    if (!ok) return;
    await ref.read(tagNotifierProvider.notifier).delete(tag.id);
  }
}

// ==================== ラベル（やりたいこと） ====================

class _WishLabelSettings extends ConsumerWidget {
  const _WishLabelSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wishLabelNotifierProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('エラー: $e'),
      data: (list) => Column(
        children: list.map((l) => _WishLabelTile(label: l)).toList(),
      ),
    );
  }
}

class _WishLabelTile extends ConsumerWidget {
  final WishLabel label;
  const _WishLabelTile({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(label.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: label.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ラベルを編集'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '名前', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(wishLabelNotifierProvider.notifier)
                  .edit(label.id, name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context,
        title: 'ラベルを削除',
        content: '「${label.name}」を削除しますか？\nすべてのやりたいことからもこのラベルが削除されます。');
    if (!ok) return;
    await ref.read(wishLabelNotifierProvider.notifier).delete(label.id);
  }
}

// ==================== アカウント ====================

class _AccountSettings extends ConsumerWidget {
  const _AccountSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final user = authAsync.value;

    return ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(user?.displayName ?? user?.email ?? 'ユーザー'),
      subtitle: user?.email != null ? Text(user!.email!) : null,
      trailing: TextButton(
        onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
        child: const Text('サインアウト'),
      ),
    );
  }
}
