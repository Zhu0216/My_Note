import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/prompt_dialogs.dart';

enum _PlanNodeAction { rename, addPhase, addTask, delete }

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

  Future<void> _handleAction(
    BuildContext context,
    PlanNode node,
    _PlanNodeAction action,
  ) async {
    switch (action) {
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
                          onAction(context, node, _PlanNodeAction.rename),
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
