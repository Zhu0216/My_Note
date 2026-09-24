import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_pickers.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/formatters.dart';
import '../../ui/prompt_dialogs.dart';
import '../../ui/related_item_picker.dart';

enum _PlanNodeAction { edit, rename, addPhase, addTask, delete }

class PlanTreeEditor extends StatelessWidget {
  const PlanTreeEditor({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final PlanDocument document;
  final ValueChanged<PlanDocument> onChanged;

  String _newId(String type) =>
      'plan-$type-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _addPhase(BuildContext context, String? parentId) async {
    final title = await promptForText(
      context,
      title: parentId == null ? '新增階段' : '新增子階段',
      label: '階段名稱',
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    document.nodes.add(
      PlanNode(
        id: _newId('phase'),
        title: title,
        type: PlanNodeType.phase,
        parentId: parentId,
      ),
    );
    onChanged(document);
  }

  Future<void> _addTask(BuildContext context, PlanNode phase) async {
    final title = await promptForText(context, title: '新增任務', label: '任務名稱');
    if (title == null || title.isEmpty || !context.mounted) return;
    document.nodes.add(
      PlanNode(
        id: _newId('task'),
        title: title,
        type: PlanNodeType.task,
        parentId: phase.id,
      ),
    );
    onChanged(document);
  }

  Future<void> _rename(BuildContext context, PlanNode node) async {
    final title = await promptForText(
      context,
      title: node.type == PlanNodeType.phase ? '重新命名階段' : '重新命名任務',
      label: '名稱',
      initialValue: node.title,
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    node.title = title;
    onChanged(document);
  }

  Future<void> _delete(BuildContext context, PlanNode node) async {
    final descendantCount = document.subtreeIds(node.id).length - 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(node.type == PlanNodeType.phase ? '刪除階段？' : '刪除任務？'),
        content: Text(
          descendantCount > 0
              ? '「${node.title}」內還有 $descendantCount 個項目，將一併刪除。'
              : '確定要刪除「${node.title}」嗎？',
        ),
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
    document.removeSubtree(node.id);
    onChanged(document);
  }

  Future<void> _edit(BuildContext context, PlanNode node) async {
    final edited = await Navigator.of(context).push<PlanNode>(
      MaterialPageRoute(builder: (_) => PlanNodeEditorPage(node: node)),
    );
    if (edited == null || !context.mounted) return;
    final index = document.nodes.indexWhere((item) => item.id == edited.id);
    if (index < 0) return;
    document.nodes[index] = edited;
    onChanged(document);
  }

  Future<void> _handleAction(
    BuildContext context,
    PlanNode node,
    _PlanNodeAction action,
  ) async {
    switch (action) {
      case _PlanNodeAction.edit:
        await _edit(context, node);
      case _PlanNodeAction.rename:
        await _rename(context, node);
      case _PlanNodeAction.addPhase:
        await _addPhase(context, node.id);
      case _PlanNodeAction.addTask:
        await _addTask(context, node);
      case _PlanNodeAction.delete:
        await _delete(context, node);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = document.progressOf(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '階段與任務',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addPhase(context, null),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('新增階段'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: progress, minHeight: 7),
        ),
        const SizedBox(height: 6),
        Text(
          '完成率 ${(progress * 100).round()}%',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (document.nodes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '尚未建立階段',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          _PlanSiblingList(
            document: document,
            parentId: null,
            depth: 0,
            onChanged: onChanged,
            onAction: _handleAction,
          ),
      ],
    );
  }
}

class _PlanSiblingList extends StatelessWidget {
  const _PlanSiblingList({
    required this.document,
    required this.parentId,
    required this.depth,
    required this.onChanged,
    required this.onAction,
  });

  final PlanDocument document;
  final String? parentId;
  final int depth;
  final ValueChanged<PlanDocument> onChanged;
  final Future<void> Function(
    BuildContext context,
    PlanNode node,
    _PlanNodeAction action,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final children = document.childrenOf(parentId);
    return ReorderableListView.builder(
      key: ValueKey('plan-children-${parentId ?? 'root'}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: children.length,
      onReorderItem: (oldIndex, newIndex) {
        document.reorderChild(parentId, oldIndex, newIndex);
        onChanged(document);
      },
      itemBuilder: (context, index) {
        final node = children[index];
        return _PlanNodeTile(
          key: ValueKey(node.id),
          document: document,
          node: node,
          index: index,
          depth: depth,
          onChanged: onChanged,
          onAction: onAction,
        );
      },
    );
  }
}

class _PlanNodeTile extends StatelessWidget {
  const _PlanNodeTile({
    super.key,
    required this.document,
    required this.node,
    required this.index,
    required this.depth,
    required this.onChanged,
    required this.onAction,
  });

  final PlanDocument document;
  final PlanNode node;
  final int index;
  final int depth;
  final ValueChanged<PlanDocument> onChanged;
  final Future<void> Function(
    BuildContext context,
    PlanNode node,
    _PlanNodeAction action,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPhase = node.type == PlanNodeType.phase;
    final phaseProgress = isPhase ? document.progressOf(node.id) : null;
    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 18, bottom: 8),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isPhase
                  ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                  : colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  const SizedBox(width: 6),
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
                  if (isPhase)
                    Icon(Icons.folder_outlined, color: colorScheme.primary)
                  else
                    Checkbox(
                      value: node.completed,
                      onChanged: (value) {
                        node.completed = value ?? false;
                        onChanged(document);
                      },
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          onAction(context, node, _PlanNodeAction.edit),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.title.isEmpty ? '未命名' : node.title,
                              style: TextStyle(
                                fontWeight: isPhase
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                decoration: !isPhase && node.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (phaseProgress != null)
                              Text(
                                '完成 ${(phaseProgress * 100).round()}%',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<_PlanNodeAction>(
                    tooltip: '項目選項',
                    onSelected: (action) => onAction(context, node, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _PlanNodeAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.tune),
                          title: Text('編輯詳細資料'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _PlanNodeAction.rename,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('重新命名'),
                        ),
                      ),
                      if (isPhase) ...[
                        const PopupMenuItem(
                          value: _PlanNodeAction.addPhase,
                          child: ListTile(
                            leading: Icon(Icons.create_new_folder_outlined),
                            title: Text('新增子階段'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _PlanNodeAction.addTask,
                          child: ListTile(
                            leading: Icon(Icons.add_task),
                            title: Text('新增任務'),
                          ),
                        ),
                      ],
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _PlanNodeAction.delete,
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
          if (isPhase && document.childrenOf(node.id).isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, left: 10),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: _PlanSiblingList(
                document: document,
                parentId: node.id,
                depth: depth + 1,
                onChanged: onChanged,
                onAction: onAction,
              ),
            ),
        ],
      ),
    );
  }
}

class PlanNodeEditorPage extends StatefulWidget {
  const PlanNodeEditorPage({super.key, required this.node});

  final PlanNode node;

  @override
  State<PlanNodeEditorPage> createState() => _PlanNodeEditorPageState();
}

class _PlanNodeEditorPageState extends State<PlanNodeEditorPage> {
  late final TextEditingController title;
  late final TextEditingController weight;
  late PlanNode working;

  bool get isTask => working.type == PlanNodeType.task;

  @override
  void initState() {
    super.initState();
    working = PlanNode.fromJson(
      widget.node.toJson(),
      fallbackId: widget.node.id,
    );
    title = TextEditingController(text: working.title);
    weight = TextEditingController(text: working.weight.toString());
  }

  @override
  void dispose() {
    title.dispose();
    weight.dispose();
    super.dispose();
  }

  Future<void> pickDueDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: working.dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => working.dueDate = picked);
  }

  Future<String?> pickRecord({required bool todo}) async {
    final store = AppStoreScope.of(context);
    return showDialog<String?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(todo ? '關聯待辦' : '關聯行程'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const ListTile(
              leading: Icon(Icons.link_off),
              title: Text('不關聯'),
            ),
          ),
          if (todo)
            for (final entry in store.todos)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.id),
                child: ListTile(title: Text(entry.title)),
              )
          else
            for (final entry in store.schedules)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.id),
                child: ListTile(title: Text(entry.title)),
              ),
        ],
      ),
    );
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
    final parsedWeight = double.tryParse(weight.text.trim());
    working.title = title.text.trim().isEmpty ? '未命名' : title.text.trim();
    working.weight = (parsedWeight ?? 1).clamp(0.01, 1000);
    Navigator.pop(context, working);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final linkedTodo = store.todos
        .where((item) => item.id == working.linkedTodoId)
        .firstOrNull;
    final linkedSchedule = store.schedules
        .where((item) => item.id == working.linkedScheduleId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(isTask ? '任務設定' : '階段設定'),
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
            controller: title,
            decoration: InputDecoration(labelText: isTask ? '任務名稱' : '階段名稱'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '權重',
              helperText: '預設為 1；重要項目可提高權重',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('截止日期'),
            subtitle: Text(
              working.dueDate == null ? '未設定' : formatDate(working.dueDate!),
            ),
            trailing: working.dueDate == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    tooltip: '清除日期',
                    onPressed: () => setState(() => working.dueDate = null),
                    icon: const Icon(Icons.close),
                  ),
            onTap: pickDueDate,
          ),
          if (isTask) ...[
            const SizedBox(height: 8),
            Text('優先級', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('無')),
                ButtonSegment(value: 1, label: Text('低')),
                ButtonSegment(value: 2, label: Text('中')),
                ButtonSegment(value: 3, label: Text('高')),
              ],
              selected: {working.priority.clamp(0, 3)},
              onSelectionChanged: (value) =>
                  setState(() => working.priority = value.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('顯示於首頁待辦'),
              value: working.showOnHome,
              onChanged: (value) => setState(() => working.showOnHome = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.checklist),
              title: const Text('關聯待辦'),
              subtitle: Text(linkedTodo?.title ?? '未關聯'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final id = await pickRecord(todo: true);
                if (id != null && mounted) {
                  setState(() => working.linkedTodoId = id.isEmpty ? null : id);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('關聯行程'),
              subtitle: Text(linkedSchedule?.title ?? '未關聯'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final id = await pickRecord(todo: false);
                if (id != null && mounted) {
                  setState(
                    () => working.linkedScheduleId = id.isEmpty ? null : id,
                  );
                }
              },
            ),
          ],
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
