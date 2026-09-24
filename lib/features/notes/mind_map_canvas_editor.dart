import 'dart:math' as math;

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
  String? connectionSourceId;
  String? selectedConnectionId;

  MindMapNode? get selected =>
      widget.document.nodes.where((node) => node.id == selectedId).firstOrNull;

  MindMapConnection? get selectedConnection => widget.document.connections
      .where((line) => line.id == selectedConnectionId)
      .firstOrNull;

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
    setState(() {
      selectedId = node.parentId ?? widget.document.rootNodeId;
      selectedConnectionId = null;
    });
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

  void autoLayout() {
    autoLayoutMindMap(widget.document, canvasSize: canvasSize);
    setState(() {});
    widget.onChanged(widget.document);
  }

  void startConnection() {
    final node = selected;
    if (node == null) return;
    setState(() {
      connectionSourceId = node.id;
      selectedConnectionId = null;
    });
  }

  void selectNode(MindMapNode node) {
    final sourceId = connectionSourceId;
    if (sourceId != null && sourceId != node.id) {
      final existing = widget.document.connections
          .where(
            (line) => line.fromNodeId == sourceId && line.toNodeId == node.id,
          )
          .firstOrNull;
      final connection =
          existing ??
          MindMapConnection(
            id: 'mind-line-${DateTime.now().microsecondsSinceEpoch}',
            fromNodeId: sourceId,
            toNodeId: node.id,
          );
      if (existing == null) {
        widget.document.connections.add(connection);
        widget.onChanged(widget.document);
      }
      setState(() {
        selectedId = node.id;
        selectedConnectionId = connection.id;
        connectionSourceId = null;
      });
      return;
    }
    setState(() {
      selectedId = node.id;
      selectedConnectionId = null;
    });
  }

  void selectConnection(String id) {
    setState(() {
      selectedConnectionId = id;
      connectionSourceId = null;
    });
  }

  void updateConnection({
    String? color,
    MindMapLineStyle? style,
    bool? directed,
  }) {
    final line = selectedConnection;
    if (line == null) return;
    if (color != null) line.color = color;
    if (style != null) line.style = style;
    if (directed != null) line.directed = directed;
    setState(() {});
    widget.onChanged(widget.document);
  }

  void deleteSelectedConnection() {
    final line = selectedConnection;
    if (line == null) return;
    widget.document.connections.removeWhere((item) => item.id == line.id);
    setState(() => selectedConnectionId = null);
    widget.onChanged(widget.document);
  }

  String connectionLabel(MindMapConnection line) {
    final from = widget.document.nodes
        .where((node) => node.id == line.fromNodeId)
        .firstOrNull;
    final to = widget.document.nodes
        .where((node) => node.id == line.toNodeId)
        .firstOrNull;
    return '${from?.title ?? '未知節點'} → ${to?.title ?? '未知節點'}';
  }

  Widget connectionToolbar(MindMapConnection line) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('mind-map-connection-toolbar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PopupMenuButton<String>(
            tooltip: '連線顏色',
            initialValue: line.color,
            onSelected: (value) => updateConnection(color: value),
            itemBuilder: (context) => _connectionColors
                .map(
                  (choice) => PopupMenuItem(
                    value: choice.$1,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _parseColor(choice.$1),
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.outline),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(choice.$2),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _parseColor(line.color),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outline),
                  ),
                ),
              ),
            ),
          ),
          SegmentedButton<MindMapLineStyle>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MindMapLineStyle.solid,
                icon: Icon(Icons.horizontal_rule),
                label: Text('實線'),
              ),
              ButtonSegment(
                value: MindMapLineStyle.dashed,
                icon: Icon(Icons.more_horiz),
                label: Text('虛線'),
              ),
            ],
            selected: {line.style},
            onSelectionChanged: (value) =>
                updateConnection(style: value.single),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            tooltip: line.directed ? '移除方向箭頭' : '顯示方向箭頭',
            onPressed: () => updateConnection(directed: !line.directed),
            icon: Icon(
              line.directed ? Icons.trending_flat : Icons.compare_arrows,
            ),
          ),
          IconButton(
            tooltip: '刪除自由連線',
            onPressed: deleteSelectedConnection,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: '完成連線編輯',
            onPressed: () => setState(() => selectedConnectionId = null),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
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
    final auxiliaryHeight = selectedConnection != null
        ? 52.0
        : connectionSourceId != null
        ? 24.0
        : 0.0;
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
              IconButton(
                tooltip: connectionSourceId == null ? '建立自由連線' : '取消連線',
                onPressed: connectionSourceId == null
                    ? startConnection
                    : () => setState(() => connectionSourceId = null),
                icon: Icon(
                  connectionSourceId == null ? Icons.timeline : Icons.close,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '管理自由連線',
                enabled: widget.document.connections.isNotEmpty,
                onSelected: selectConnection,
                itemBuilder: (context) => widget.document.connections
                    .map(
                      (line) => PopupMenuItem(
                        value: line.id,
                        child: Text(connectionLabel(line)),
                      ),
                    )
                    .toList(),
                icon: const Icon(Icons.account_tree_outlined),
              ),
              IconButton(
                tooltip: '一鍵排版',
                onPressed: autoLayout,
                icon: const Icon(Icons.auto_fix_high),
              ),
            ],
          ),
        ),
        if (connectionSourceId != null) ...[
          const SizedBox(height: 4),
          Text(
            '請點選另一個節點以建立自由連線',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (selectedConnection case final line?) ...[
          const SizedBox(height: 4),
          connectionToolbar(line),
        ],
        const SizedBox(height: 8),
        Container(
          height: 520 - auxiliaryHeight,
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
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MindMapConnectionPainter(
                        document: widget.document,
                        visibleNodeIds: widget.document.nodes
                            .where(isVisible)
                            .map((node) => node.id)
                            .toSet(),
                        nodeSize: nodeSize,
                      ),
                    ),
                  ),
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
                          onPointerDown: (_) {
                            if (connectionSourceId != null) return;
                            setState(() {
                              selectedId = item.id;
                              selectedConnectionId = null;
                              movingNodeId = item.locked ? null : item.id;
                            });
                          },
                          onPointerMove: (event) {
                            if (movingNodeId == item.id) {
                              moveNode(item, event.delta);
                            }
                          },
                          onPointerUp: (_) {
                            if (connectionSourceId != null) {
                              selectNode(item);
                              return;
                            }
                            if (movingNodeId == item.id) {
                              widget.onChanged(widget.document);
                            }
                            setState(() => movingNodeId = null);
                          },
                          onPointerCancel: (_) =>
                              setState(() => movingNodeId = null),
                          child: _MindMapNodeCard(
                            node: item,
                            selected: selectedId == item.id,
                            isRoot: item.id == widget.document.rootNodeId,
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

const _connectionColors = <(String, String)>[
  ('#7C8B5F', '苔綠'),
  ('#2563EB', '藍色'),
  ('#0F766E', '青綠'),
  ('#B45309', '琥珀'),
  ('#B91C1C', '紅色'),
  ('#6D28D9', '紫色'),
  ('#374151', '深灰'),
];

void autoLayoutMindMap(
  MindMapDocument document, {
  Size canvasSize = const Size(1200, 800),
}) {
  final root = document.nodes.firstWhere(
    (node) => node.id == document.rootNodeId,
  );
  final queue = <(MindMapNode, int)>[(root, 0)];
  final depthById = <String, int>{};
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final entry = queue.removeAt(0);
    final node = entry.$1;
    final depth = entry.$2;
    if (!visited.add(node.id)) continue;
    depthById[node.id] = depth;
    for (final child in document.nodes.where(
      (item) => item.parentId == node.id,
    )) {
      queue.add((child, depth + 1));
    }
  }

  for (final node in document.nodes) {
    if (!visited.contains(node.id)) depthById[node.id] = 1;
  }
  final levels = <int, List<MindMapNode>>{};
  for (final node in document.nodes) {
    if (node.id == document.rootNodeId || node.locked) continue;
    final depth = math.max(1, depthById[node.id] ?? 1);
    levels.putIfAbsent(depth, () => []).add(node);
  }
  for (final entry in levels.entries) {
    final nodes = entry.value;
    final spacing = canvasSize.height / (nodes.length + 1);
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      node.x = (root.x + entry.key * 220)
          .clamp(0, canvasSize.width - 164)
          .toDouble();
      node.y = (spacing * (index + 1) - 38)
          .clamp(0, canvasSize.height - 76)
          .toDouble();
    }
  }
}

class _MindMapConnectionPainter extends CustomPainter {
  const _MindMapConnectionPainter({
    required this.document,
    required this.visibleNodeIds,
    required this.nodeSize,
  });

  final MindMapDocument document;
  final Set<String> visibleNodeIds;
  final Size nodeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final node in document.nodes) node.id: node};
    for (final node in document.nodes) {
      if (node.parentId == null || !visibleNodeIds.contains(node.id)) continue;
      final parent = byId[node.parentId];
      if (parent != null && visibleNodeIds.contains(parent.id)) {
        _drawLine(canvas, parent, node, const Color(0xff9aa4b2), false, false);
      }
    }
    for (final line in document.connections) {
      final from = byId[line.fromNodeId];
      final to = byId[line.toNodeId];
      if (from == null ||
          to == null ||
          !visibleNodeIds.contains(from.id) ||
          !visibleNodeIds.contains(to.id)) {
        continue;
      }
      _drawLine(
        canvas,
        from,
        to,
        _parseColor(line.color),
        line.style == MindMapLineStyle.dashed,
        line.directed,
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    MindMapNode from,
    MindMapNode to,
    Color color,
    bool dashed,
    bool directed,
  ) {
    final start = Offset(
      from.x + nodeSize.width / 2,
      from.y + nodeSize.height / 2,
    );
    final end = Offset(to.x + nodeSize.width / 2, to.y + nodeSize.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      canvas.drawLine(start, end, paint);
    } else {
      final vector = end - start;
      final distance = vector.distance;
      if (distance == 0) return;
      final direction = vector / distance;
      for (double offset = 0; offset < distance; offset += 12) {
        canvas.drawLine(
          start + direction * offset,
          start + direction * (offset + 7).clamp(0, distance),
          paint,
        );
      }
    }
    if (directed) {
      final angle = (start - end).direction;
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx + 12 * math.cos(angle - 0.45),
          end.dy + 12 * math.sin(angle - 0.45),
        )
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx + 12 * math.cos(angle + 0.45),
          end.dy + 12 * math.sin(angle + 0.45),
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapConnectionPainter oldDelegate) => true;
}
