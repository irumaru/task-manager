import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/priority.dart';
import '../../../domain/models/status.dart';
import '../../../domain/models/tag.dart';
import '../../providers/priority_provider.dart';
import '../../providers/status_provider.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/confirm_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: const [
          _SectionHeader('優先度'),
          _PrioritySettings(),
          _SectionHeader('ステータス'),
          _StatusSettings(),
          _SectionHeader('タグ'),
          _TagSettings(),
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

// ==================== 優先度 ====================

class _PrioritySettings extends ConsumerWidget {
  const _PrioritySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(priorityNotifierProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('エラー: $e'),
      data: (list) => Column(
        children: [
          ...list.map((p) => _PriorityTile(priority: p)),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('優先度を追加'),
            onTap: () => _showDialog(context, ref, null),
          ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref, Priority? existing) {
    final ctrl = TextEditingController(text: existing?.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? '優先度を追加' : '優先度を編集'),
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
              final notifier = ref.read(priorityNotifierProvider.notifier);
              if (existing == null) {
                await notifier.add(name);
              } else {
                await notifier.edit(existing.id, name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _PriorityTile extends ConsumerWidget {
  final Priority priority;
  const _PriorityTile({required this.priority});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(priority.name),
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
    final ctrl = TextEditingController(text: priority.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('優先度を編集'),
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
                  .read(priorityNotifierProvider.notifier)
                  .edit(priority.id, name);
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
        title: '優先度を削除',
        content:
            '「${priority.name}」を削除しますか？\nこの優先度を持つタスクの優先度は空になります。');
    if (!ok) return;
    await ref.read(priorityNotifierProvider.notifier).delete(priority.id);
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
