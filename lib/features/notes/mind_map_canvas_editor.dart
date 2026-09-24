import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/prompt_dialogs.dart';

class MindMapCanvasEditor extends StatefulWidget {
  const MindMapCanvasEditor({
    super.key,
    required this.document,
    required this.onChanged,
  });

  final MindMapDocument document;
  final ValueChanged<MindMapDocument> onChanged;

  @override
  State<MindMapCanvasEditor> createState() => _MindMapCanvasEditorState();
}

class _MindMapCanvasEditorState extends State<MindMapCanvasEditor> {
  static const canvasSize = Size(1200, 800);
  static const nodeSize = Size(164, 76);
  final transform = TransformationController();
  String? selectedId;
  String? movingNodeId;

  MindMapNode? get selected =>
      widget.document.nodes.where((node) => node.id == selectedId).firstOrNull;

  MindMapNode get root => widget.document.nodes.firstWhere(
    (node) => node.id == widget.document.rootNodeId,
  );

  @override
  void initState() {
    super.initState();
    selectedId = widget.document.rootNodeId;
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  bool isVisible(MindMapNode node) {
    var current = node;
    final visited = <String>{};
    while (current.parentId != null && visited.add(current.id)) {
      final parent = widget.document.nodes
          .where((candidate) => candidate.id == current.parentId)
          .firstOrNull;
      if (parent == null || !parent.expanded) return false;
      current = parent;
    }
    return true;
  }

  Future<void> addChild() async {
    final parent = selected ?? root;
    final title = await promptForText(context, title: '新增節點', label: '節點標題');
    if (title == null || title.isEmpty || !mounted) return;
    final siblingCount = widget.document.nodes
        .where((node) => node.parentId == parent.id)
        .length;
    final node = MindMapNode(
      id: 'mind-node-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      parentId: parent.id,
      x: (parent.x + 220).clamp(0, canvasSize.width - nodeSize.width),
      y: (parent.y + siblingCount * 110).clamp(
        0,
        canvasSize.height - nodeSize.height,
      ),
      color: parent.color,
    );
    widget.document.nodes.add(node);
    setState(() => selectedId = node.id);
    widget.onChanged(widget.document);
  }

  Future<void> renameSelected() async {
    final node = selected;
    if (node == null) return;
    final title = await promptForText(
      context,
      title: '重新命名節點',
      label: '節點標題',
      initialValue: node.title,
    );
    if (title == null || title.isEmpty || !mounted) return;
    node.title = title;
    setState(() {});
    widget.onChanged(widget.document);
  }

  Set<String> subtreeIds(String nodeId) {
    final ids = <String>{nodeId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in widget.document.nodes) {
        if (node.parentId != null &&
            ids.contains(node.parentId) &&
            ids.add(node.id)) {
          changed = true;
        }
      }
    }
    return ids;
  }

  Future<void> deleteSelected() async {
    final node = selected;
    if (node == null || node.id == widget.document.rootNodeId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除節點？'),
        content: Text('「${node.title}」與其子節點將一併刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removed = subtreeIds(node.id);
    widget.document.nodes.removeWhere((item) => removed.contains(item.id));
    widget.document.connections.removeWhere(
      (line) =>
          removed.contains(line.fromNodeId) || removed.contains(line.toNodeId),
    );
    setState(() => selectedId = node.parentId ?? widget.document.rootNodeId);
    widget.onChanged(widget.document);
  }

  void toggleLock() {
    final node = selected;
    if (node == null) return;
    node.locked = !node.locked;
    setState(() {});
    widget.onChanged(widget.document);
  }

  void toggleExpanded() {
    final node = selected;
    if (node == null) return;
    node.expanded = !node.expanded;
    setState(() {});
    widget.onChanged(widget.document);
  }

  void moveNode(MindMapNode node, Offset delta) {
    if (node.locked) return;
    final scale = transform.value.getMaxScaleOnAxis();
    node.x = (node.x + delta.dx / scale).clamp(
      0,
      canvasSize.width - nodeSize.width,
    );
    node.y = (node.y + delta.dy / scale).clamp(
      0,
      canvasSize.height - nodeSize.height,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final node = selected;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              IconButton.filledTonal(
                tooltip: '新增子節點',
                onPressed: addChild,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: '重新命名',
                onPressed: node == null ? null : renameSelected,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: node?.locked == true ? '解除鎖定' : '鎖定節點',
                onPressed: node == null ? null : toggleLock,
                icon: Icon(node?.locked == true ? Icons.lock : Icons.lock_open),
              ),
              IconButton(
                tooltip: node?.expanded == false ? '展開子節點' : '收合子節點',
                onPressed: node == null ? null : toggleExpanded,
                icon: Icon(
                  node?.expanded == false
                      ? Icons.unfold_more
                      : Icons.unfold_less,
                ),
              ),
              IconButton(
                tooltip: '刪除節點',
                onPressed: node == null || node.id == widget.document.rootNodeId
                    ? null
                    : deleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 520,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InteractiveViewer(
            transformationController: transform,
            panEnabled: movingNodeId == null,
            constrained: false,
            minScale: 0.45,
            maxScale: 2.4,
            boundaryMargin: const EdgeInsets.all(160),
            child: SizedBox.fromSize(
              size: canvasSize,
              child: Stack(
                children: [
                  for (final item in widget.document.nodes.where(isVisible))
                    Positioned(
                      key: ValueKey(item.id),
                      left: item.x,
                      top: item.y,
                      width: nodeSize.width,
                      height: nodeSize.height,
                      child: MouseRegion(
                        cursor: item.locked
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.move,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => setState(() {
                            selectedId = item.id;
                            movingNodeId = item.locked ? null : item.id;
                          }),
                          onPointerMove: (event) {
                            if (movingNodeId == item.id) {
                              moveNode(item, event.delta);
                            }
                          },
                          onPointerUp: (_) {
                            if (movingNodeId == item.id) {
                              widget.onChanged(widget.document);
                            }
                            setState(() => movingNodeId = null);
                          },
                          onPointerCancel: (_) =>
                              setState(() => movingNodeId = null),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => selectedId = item.id),
                            onDoubleTap: () {
                              setState(() => selectedId = item.id);
                              renameSelected();
                            },
                            child: _MindMapNodeCard(
                              node: item,
                              selected: selectedId == item.id,
                              isRoot: item.id == widget.document.rootNodeId,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MindMapNodeCard extends StatelessWidget {
  const _MindMapNodeCard({
    required this.node,
    required this.selected,
    required this.isRoot,
  });

  final MindMapNode node;
  final bool selected;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(node.color);
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(
          color: selected ? colorScheme.primary : color,
          width: selected ? 2.5 : 1.2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              isRoot ? Icons.radio_button_checked : Icons.circle_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title.isEmpty ? '未命名節點' : node.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (node.locked) const Icon(Icons.lock, size: 16),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String value) {
  final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return parsed == null ? const Color(0xff7c8b5f) : Color(0xff000000 | parsed);
}
