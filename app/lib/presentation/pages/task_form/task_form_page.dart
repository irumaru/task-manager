import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/task.dart';
import '../../../domain/models/tag.dart';
import '../../providers/task_provider.dart';
import '../../providers/priority_provider.dart';
import '../../providers/status_provider.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../../core/utils/date_utils.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  final Task? task;

  const TaskFormPage({super.key, this.task});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _tagInputController;

  DateTime? _dueDate;
  String? _priorityId;
  String? _statusId;
  final List<Tag> _selectedTags = [];
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _memoController = TextEditingController(text: task?.memo ?? '');
    _tagInputController = TextEditingController();
    _dueDate = task?.dueDate;
    _priorityId = task?.priority?.id ?? task?.priorityId;
    _statusId = task?.status?.id ?? task?.statusId;
    if (task != null) {
      _selectedTags.addAll(task.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_statusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ステータスを選択してください')),
      );
      return;
    }
    setState(() => _isSaving = true);

    final tagIds = _selectedTags.map((t) => t.id).toList();
    final notifier = ref.read(taskNotifierProvider.notifier);
    final memo = _memoController.text.trim();

    if (_isEditing) {
      await notifier.updateTask(
        id: widget.task!.id,
        title: _titleController.text.trim(),
        memo: memo.isEmpty ? null : memo,
        clearMemo: memo.isEmpty,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        priorityId: _priorityId,
        clearPriority: _priorityId == null,
        statusId: _statusId,
        tagIds: tagIds,
      );
    } else {
      await notifier.addTask(
        title: _titleController.text.trim(),
        memo: memo.isEmpty ? null : memo,
        dueDate: _dueDate,
        statusId: _statusId!,
        priorityId: _priorityId,
        tagIds: tagIds,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'タスクを削除',
      content: '「${widget.task!.title}」を削除しますか？',
    );
    if (!confirmed || !mounted) return;
    await ref.read(taskNotifierProvider.notifier).deleteTask(widget.task!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_selectedTags.any((t) => t.name == trimmed)) return;

    final id = await ref.read(tagNotifierProvider.notifier).findOrCreate(trimmed);
    setState(() {
      _selectedTags.add(Tag(id: id, name: trimmed));
      _tagInputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final priorities = ref.watch(priorityNotifierProvider).value ?? [];
    final statuses = ref.watch(statusNotifierProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'タスクを編集' : 'タスクを追加'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              color: Colors.red,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // タイトル
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),

            // メモ
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 期限日
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_dueDate == null
                  ? '期限日を設定'
                  : AppDateUtils.formatDate(_dueDate)),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 優先度
            DropdownButtonFormField<String?>(
              initialValue: _priorityId,
              decoration: const InputDecoration(
                labelText: '優先度',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('なし')),
                ...priorities.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _priorityId = v),
            ),
            const SizedBox(height: 16),

            // ステータス
            DropdownButtonFormField<String?>(
              initialValue: _statusId,
              decoration: const InputDecoration(
                labelText: 'ステータス *',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('なし')),
                ...statuses.map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.name))),
              ],
              onChanged: (v) => setState(() => _statusId = v),
            ),
            const SizedBox(height: 16),

            // タグ
            Text('タグ', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._selectedTags.map((tag) => Chip(
                      label: Text(tag.name),
                      onDeleted: () =>
                          setState(() => _selectedTags.remove(tag)),
                    )),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    decoration: const InputDecoration(
                      hintText: 'タグを入力してEnter',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagInputController.text),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 保存ボタン
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
