import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/wish.dart';
import '../../../domain/models/wish_label.dart';
import '../../providers/wish_provider.dart';
import '../../providers/wish_label_provider.dart';
import '../../widgets/confirm_dialog.dart';

class WishFormPage extends ConsumerStatefulWidget {
  final Wish? wish;

  const WishFormPage({super.key, this.wish});

  @override
  ConsumerState<WishFormPage> createState() => _WishFormPageState();
}

class _WishFormPageState extends ConsumerState<WishFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;
  late final TextEditingController _labelInputController;
  late final FocusNode _labelInputFocusNode;

  final List<WishLabel> _selectedLabels = [];
  bool _isSaving = false;

  bool get _isEditing => widget.wish != null;

  @override
  void initState() {
    super.initState();
    final wish = widget.wish;
    _titleController = TextEditingController(text: wish?.title ?? '');
    _detailController = TextEditingController(text: wish?.detail ?? '');
    _labelInputController = TextEditingController();
    _labelInputFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _labelInputController.dispose();
    _labelInputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initSelectedLabels() async {
    if (_isEditing && _selectedLabels.isEmpty) {
      final allLabels = await ref.read(wishLabelNotifierProvider.future);
      final ids = widget.wish!.labelIds;
      _selectedLabels.addAll(allLabels.where((l) => ids.contains(l.id)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_labelInputController.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ラベル名が確定されていません。Enter で確定するか、入力を消去してください。'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    final detail = _detailController.text.trim();
    final labelIds = _selectedLabels.map((l) => l.id).toList();
    final notifier = ref.read(wishNotifierProvider.notifier);

    try {
      if (_isEditing) {
        await notifier.updateWish(
          id: widget.wish!.id,
          title: _titleController.text.trim(),
          detail: detail.isEmpty ? null : detail,
          labelIds: labelIds,
        );
      } else {
        await notifier.addWish(
          title: _titleController.text.trim(),
          detail: detail.isEmpty ? null : detail,
          labelIds: labelIds,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'やりたいことを削除',
      content: '「${widget.wish!.title}」を削除しますか？',
    );
    if (!confirmed || !mounted) return;
    await ref.read(wishNotifierProvider.notifier).deleteWish(widget.wish!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addLabelByName() async {
    final trimmed = _labelInputController.text.trim();
    if (trimmed.isEmpty) return;
    if (_selectedLabels.any((l) => l.name == trimmed)) {
      _labelInputController.clear();
      return;
    }
    final id =
        await ref.read(wishLabelNotifierProvider.notifier).findOrCreate(trimmed);
    if (!mounted) return;
    setState(() {
      _selectedLabels.add(WishLabel(id: id, name: trimmed));
    });
    _labelInputController.clear();
  }

  void _addExistingLabel(WishLabel label) {
    if (_selectedLabels.any((l) => l.id == label.id)) {
      _labelInputController.clear();
      return;
    }
    setState(() => _selectedLabels.add(label));
    _labelInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final allLabels = ref.watch(wishLabelNotifierProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'やりたいことを編集' : 'やりたいことを追加'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
              color: Colors.red,
            ),
        ],
      ),
      body: FutureBuilder(
        future: _initSelectedLabels(),
        builder: (context, _) => Form(
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
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                ],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
                autofocus: !_isEditing,
              ),
              const SizedBox(height: 16),

              // 詳細
              TextFormField(
                controller: _detailController,
                decoration: const InputDecoration(
                  labelText: '詳細',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: null,
              ),
              const SizedBox(height: 16),

              // ラベル
              Text('ラベル', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedLabels
                    .map((label) => Chip(
                          label: Text(label.name),
                          onDeleted: () =>
                              setState(() => _selectedLabels.remove(label)),
                        ))
                    .toList(),
              ),
              Autocomplete<WishLabel>(
                textEditingController: _labelInputController,
                focusNode: _labelInputFocusNode,
                displayStringForOption: (l) => l.name,
                optionsBuilder: (textEditingValue) {
                  final input = textEditingValue.text.trim().toLowerCase();
                  if (input.isEmpty) return const Iterable<WishLabel>.empty();
                  return allLabels.where((l) {
                    if (_selectedLabels.any((s) => s.id == l.id)) return false;
                    return l.name.toLowerCase().contains(input);
                  });
                },
                onSelected: _addExistingLabel,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'ラベルを入力してEnter',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addLabelByName(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: _addLabelByName,
                      ),
                    ],
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 400,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final label = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(label.name),
                              onTap: () => onSelected(label),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
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
      ),
    );
  }
}
