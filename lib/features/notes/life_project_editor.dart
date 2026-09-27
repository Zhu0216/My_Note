import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_pickers.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/formatters.dart';
import '../../ui/related_item_picker.dart';

enum _LifeItemAction { edit, delete }

class LifeProjectEditor extends StatelessWidget {
  const LifeProjectEditor({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final LifeProjectDocument document;
  final ValueChanged<LifeProjectDocument> onChanged;

  List<LifeProjectItem> get orderedItems =>
      [...document.items]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  Future<void> _pickDate(BuildContext context, {required bool target}) async {
    final current = target ? document.targetDate : document.startDate;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) return;
    if (target) {
      document.targetDate = picked;
    } else {
      document.startDate = picked;
    }
    onChanged(document);
  }

  Future<void> _editItem(BuildContext context, LifeProjectItem item) async {
    final edited = await Navigator.of(context).push<LifeProjectItem>(
      MaterialPageRoute(builder: (_) => LifeProjectItemEditorPage(item: item)),
    );
    if (edited == null || !context.mounted) return;
    final index = document.items.indexWhere((entry) => entry.id == edited.id);
    if (index < 0) {
      document.items.add(edited);
    } else {
      document.items[index] = edited;
    }
    _normalizeOrder();
    onChanged(document);
  }

  Future<void> _addItem(BuildContext context) async {
    final item = LifeProjectItem(
      id: 'life-item-${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      sortOrder: document.items.length,
    );
    await _editItem(context, item);
  }

  Future<void> _deleteItem(BuildContext context, LifeProjectItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除人生專案項目？'),
        content: Text('確定要刪除「${item.name.isEmpty ? '未命名項目' : item.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    document.items.removeWhere((entry) => entry.id == item.id);
    _normalizeOrder();
    onChanged(document);
  }

  void _normalizeOrder() {
    final items = orderedItems;
    for (var index = 0; index < items.length; index++) {
      items[index].sortOrder = index;
    }
    document.items
      ..clear()
      ..addAll(items);
  }

  void _reorder(int oldIndex, int newIndex) {
    final items = orderedItems;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    for (var index = 0; index < items.length; index++) {
      items[index].sortOrder = index;
    }
    document.items
      ..clear()
      ..addAll(items);
    onChanged(document);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = orderedItems;
    final progress = document.weightedProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '專案概覽',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<LifeProjectStatus>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: LifeProjectStatus.active,
                    icon: Icon(Icons.play_circle_outline),
                    label: Text('進行中'),
                  ),
                  ButtonSegment(
                    value: LifeProjectStatus.completed,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('完成'),
                  ),
                ],
                selected: {document.status},
                onSelectionChanged: (value) {
                  document.status = value.single;
                  onChanged(document);
                },
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: progress, minHeight: 9),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context, target: false),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      document.startDate == null
                          ? '開始日期'
                          : formatDate(document.startDate!),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context, target: true),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(
                      document.targetDate == null
                          ? '目標日期'
                          : formatDate(document.targetDate!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '專案項目',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addItem(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增項目'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '尚未建立專案項目',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _LifeProjectItemCard(
                  item: item,
                  index: index,
                  onTap: () => _editItem(context, item),
                  onAction: (action) {
                    switch (action) {
                      case _LifeItemAction.edit:
                        _editItem(context, item);
                      case _LifeItemAction.delete:
                        _deleteItem(context, item);
                    }
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LifeProjectItemCard extends StatelessWidget {
  const _LifeProjectItemCard({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onAction,
  });

  final LifeProjectItem item;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<_LifeItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = item.displayMode == LifeItemDisplayMode.money
        ? item.targetAmount <= 0
              ? 0.0
              : (item.manualCurrentAmount / item.targetAmount).clamp(0.0, 1.0)
        : item.progress.clamp(0.0, 1.0);
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                item.displayMode == LifeItemDisplayMode.money
                    ? Icons.savings_outlined
                    : Icons.task_alt,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name.isEmpty ? '未命名項目' : item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(value: progress, minHeight: 5),
                    const SizedBox(height: 5),
                    Text(
                      item.displayMode == LifeItemDisplayMode.money
                          ? '${item.manualCurrentAmount.toStringAsFixed(0)} / ${item.targetAmount.toStringAsFixed(0)} · ${item.links.length} 個關聯'
                          : '權重 ${item.weight.toStringAsFixed(1)} · ${item.links.length} 個關聯',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_LifeItemAction>(
                tooltip: '項目選項',
                onSelected: onAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _LifeItemAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('編輯'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _LifeItemAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('刪除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LifeProjectItemEditorPage extends StatefulWidget {
  const LifeProjectItemEditorPage({super.key, required this.item});

  final LifeProjectItem item;

  @override
  State<LifeProjectItemEditorPage> createState() =>
      _LifeProjectItemEditorPageState();
}

class _LifeProjectItemEditorPageState extends State<LifeProjectItemEditorPage> {
  late LifeProjectItem working;
  late final TextEditingController name;
  late final TextEditingController weight;
  late final TextEditingController target;
  late final TextEditingController current;
  late final TextEditingController progress;

  @override
  void initState() {
    super.initState();
    working = LifeProjectItem.fromJson(
      widget.item.toJson(),
      fallbackId: widget.item.id,
      fallbackOrder: widget.item.sortOrder,
    );
    name = TextEditingController(text: working.name);
    weight = TextEditingController(text: working.weight.toString());
    target = TextEditingController(text: working.targetAmount.toString());
    current = TextEditingController(
      text: working.manualCurrentAmount.toString(),
    );
    progress = TextEditingController(
      text: (working.progress * 100).round().toString(),
    );
  }

  @override
  void dispose() {
    name.dispose();
    weight.dispose();
    target.dispose();
    current.dispose();
    progress.dispose();
    super.dispose();
  }

  Future<void> editLinks() async {
    final result = await showRelatedItemPicker(
      context,
      store: AppStoreScope.of(context),
      initialLinks: working.links,
    );
    if (result != null && mounted) setState(() => working.links = result);
  }

  void save() {
    working.name = name.text.trim().isEmpty ? '未命名項目' : name.text.trim();
    working.weight = (double.tryParse(weight.text.trim()) ?? 1).clamp(
      0.01,
      1000,
    );
    if (working.displayMode == LifeItemDisplayMode.money) {
      working.targetAmount = double.tryParse(target.text.trim()) ?? 0;
      working.manualCurrentAmount = double.tryParse(current.text.trim()) ?? 0;
      working.completed =
          working.targetAmount > 0 &&
          working.manualCurrentAmount >= working.targetAmount;
    } else {
      working.progress = ((double.tryParse(progress.text.trim()) ?? 0) / 100)
          .clamp(0, 1);
      working.completed = working.progress >= 1;
    }
    Navigator.pop(context, working);
  }

  @override
  Widget build(BuildContext context) {
    final money = working.displayMode == LifeItemDisplayMode.money;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('專案項目'),
        actions: [
          IconButton(
            tooltip: '儲存',
            onPressed: save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '項目名稱'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<LifeItemDisplayMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: LifeItemDisplayMode.money,
                icon: Icon(Icons.savings_outlined),
                label: Text('金錢'),
              ),
              ButtonSegment(
                value: LifeItemDisplayMode.progress,
                icon: Icon(Icons.task_alt),
                label: Text('狀態／完成率'),
              ),
            ],
            selected: {working.displayMode},
            onSelectionChanged: (value) =>
                setState(() => working.displayMode = value.single),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '權重',
              helperText: '總完成率會依項目權重計算',
            ),
          ),
          const SizedBox(height: 12),
          if (money) ...[
            TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '目標金額'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: current,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '目前金額'),
            ),
          ] else
            TextField(
              controller: progress,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '完成率',
                suffixText: '%',
              ),
            ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hub_outlined),
            title: const Text('關聯項目'),
            subtitle: Text('${working.links.length} 項'),
            trailing: const Icon(Icons.chevron_right),
            onTap: editLinks,
          ),
        ],
      ),
    );
  }
}
