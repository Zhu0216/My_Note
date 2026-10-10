import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_store_scope.dart';
import '../../ui/prompt_dialogs.dart';
import '../../ui/related_item_picker.dart';

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
  final transform = TransformationController();
  final canvasFocusNode = FocusNode(debugLabel: 'mind-map-canvas');
  final nodeToolbarController = ScrollController();
  final outlineScrollController = ScrollController();
  final outlineKeys = <String, GlobalKey>{};
  String? selectedId;
  String? movingNodeId;
  String? connectionSourceId;
  String? selectedConnectionId;
  double outlineWidth = 260;
  Size canvasViewportSize = Size.zero;
  int narrowViewIndex = 1;
  bool toolbarCanScrollLeft = false;
  bool toolbarCanScrollRight = false;

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
    nodeToolbarController.addListener(updateToolbarScrollState);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => updateToolbarScrollState(),
    );
  }

  @override
  void dispose() {
    transform.dispose();
    canvasFocusNode.dispose();
    nodeToolbarController
      ..removeListener(updateToolbarScrollState)
      ..dispose();
    outlineScrollController.dispose();
    super.dispose();
  }

  void updateToolbarScrollState() {
    if (!mounted || !nodeToolbarController.hasClients) return;
    final position = nodeToolbarController.position;
    final left = position.pixels > position.minScrollExtent + 1;
    final right = position.pixels < position.maxScrollExtent - 1;
    if (left == toolbarCanScrollLeft && right == toolbarCanScrollRight) return;
    setState(() {
      toolbarCanScrollLeft = left;
      toolbarCanScrollRight = right;
    });
  }

  void scrollNodeToolbar(double direction) {
    if (!nodeToolbarController.hasClients) return;
    final position = nodeToolbarController.position;
    final target = (position.pixels + direction * 240).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    nodeToolbarController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  List<(MindMapNode, int)> get outlineNodes {
    final result = <(MindMapNode, int)>[];
    final visited = <String>{};

    void append(String? parentId, int depth) {
      for (final node in widget.document.nodes.where(
        (item) => item.parentId == parentId,
      )) {
        if (!visited.add(node.id)) continue;
        result.add((node, depth));
        if (node.expanded) append(node.id, depth + 1);
      }
    }

    final rootNode = root;
    visited.add(rootNode.id);
    result.add((rootNode, 0));
    if (rootNode.expanded) append(rootNode.id, 1);
    for (final node in widget.document.nodes) {
      if (visited.add(node.id)) result.add((node, 0));
    }
    return result;
  }

  void revealOutlineSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemContext = outlineKeys[selectedId]?.currentContext;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 180),
          alignment: 0.45,
        );
      }
    });
  }

  void centerNode(MindMapNode node) {
    if (canvasViewportSize.isEmpty) return;
    final scale = transform.value.getMaxScaleOnAxis().clamp(0.45, 2.4);
    final size = mindMapNodeSize(widget.document, node);
    final center = Offset(node.x + size.width / 2, node.y + size.height / 2);
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, 1)
      ..setTranslationRaw(
        canvasViewportSize.width / 2 - center.dx * scale,
        canvasViewportSize.height / 2 - center.dy * scale,
        0,
      );
  }

  void fitCanvas() {
    if (canvasViewportSize.isEmpty) return;
    final scale = math
        .min(
          canvasViewportSize.width / canvasSize.width,
          canvasViewportSize.height / canvasSize.height,
        )
        .clamp(0.45, 1.0);
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, 1)
      ..setTranslationRaw(
        (canvasViewportSize.width - canvasSize.width * scale) / 2,
        (canvasViewportSize.height - canvasSize.height * scale) / 2,
        0,
      );
  }

  void zoomBy(double factor) {
    final current = transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.45, 2.4);
    final node = selected ?? root;
    final size = mindMapNodeSize(widget.document, node);
    final center = Offset(node.x + size.width / 2, node.y + size.height / 2);
    transform.value = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(2, 2, 1)
      ..setTranslationRaw(
        canvasViewportSize.width / 2 - center.dx * next,
        canvasViewportSize.height / 2 - center.dy * next,
        0,
      );
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
      x: (parent.x + 220).clamp(0, canvasSize.width - 220),
      y: (parent.y + siblingCount * 110).clamp(0, canvasSize.height - 88),
      color: parent.color,
    );
    widget.document.nodes.add(node);
    setState(() => selectedId = node.id);
    widget.onChanged(widget.document);
  }

  Future<void> addSibling() async {
    final current = selected ?? root;
    final parent = widget.document.nodes
        .where((node) => node.id == current.parentId)
        .firstOrNull;
    if (parent == null) return;
    final title = await promptForText(context, title: '新增同層節點', label: '節點標題');
    if (title == null || title.isEmpty || !mounted) return;
    final siblingCount = widget.document.nodes
        .where((node) => node.parentId == parent.id)
        .length;
    final node = MindMapNode(
      id: 'mind-node-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      parentId: parent.id,
      x: (current.x + 40).clamp(0, canvasSize.width - 220),
      y: (parent.y + siblingCount * 96).clamp(0, canvasSize.height - 88),
      color: current.color,
    );
    final currentIndex = widget.document.nodes.indexOf(current);
    widget.document.nodes.insert(currentIndex + 1, node);
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

  Future<void> editSelectedLinks() async {
    final node = selected;
    if (node == null) return;
    final result = await showRelatedItemPicker(
      context,
      store: AppStoreScope.of(context),
      initialLinks: node.links,
    );
    if (result == null || !mounted) return;
    node.links = result;
    setState(() {});
    widget.onChanged(widget.document);
  }

  void updateSelectedColor(String color) {
    final node = selected;
    if (node == null) return;
    node.color = color;
    setState(() {});
    widget.onChanged(widget.document);
  }

  void updateNodeShape(MindMapNodeShape shape) {
    widget.document.nodeShape = shape;
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
      revealOutlineSelection();
      return;
    }
    setState(() {
      selectedId = node.id;
      selectedConnectionId = null;
    });
    revealOutlineSelection();
  }

  void selectFromOutline(MindMapNode node) {
    selectNode(node);
    setState(() => narrowViewIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) centerNode(node);
    });
  }

  void reorderOutline(int oldIndex, int newIndex) {
    final visible = outlineNodes;
    if (!reorderMindMapOutlineNodes(
      widget.document,
      visible,
      oldIndex,
      newIndex,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('同一階層的節點才可調整順序')));
      return;
    }
    setState(() {});
    widget.onChanged(widget.document);
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
    final size = mindMapNodeSize(widget.document, node);
    node.x = (node.x + delta.dx / scale).clamp(
      0,
      canvasSize.width - size.width,
    );
    node.y = (node.y + delta.dy / scale).clamp(
      0,
      canvasSize.height - size.height,
    );
    setState(() {});
  }

  KeyEventResult handleCanvasKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || selected == null) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      addChild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      addSibling();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete &&
        selectedId != widget.document.rootNodeId) {
      deleteSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget buildNodeToolbar() {
    final node = selected;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            tooltip: '向左查看更多工具',
            onPressed: toolbarCanScrollLeft
                ? () => scrollNodeToolbar(-1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: ListView(
              controller: nodeToolbarController,
              scrollDirection: Axis.horizontal,
              children: [
                IconButton.filledTonal(
                  tooltip: '新增子節點',
                  onPressed: addChild,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: '新增同層節點',
                  onPressed:
                      node == null || node.id == widget.document.rootNodeId
                      ? null
                      : addSibling,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: '重新命名',
                  onPressed: node == null ? null : renameSelected,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: node?.locked == true ? '解除鎖定' : '鎖定節點',
                  onPressed: node == null ? null : toggleLock,
                  icon: Icon(
                    node?.locked == true ? Icons.lock : Icons.lock_open,
                  ),
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
                  tooltip: '關聯項目',
                  onPressed: node == null ? null : editSelectedLinks,
                  icon: Badge.count(
                    count: node?.links.length ?? 0,
                    isLabelVisible: (node?.links.isNotEmpty ?? false),
                    child: const Icon(Icons.link),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '節點顏色',
                  enabled: node != null,
                  initialValue: node?.color,
                  onSelected: updateSelectedColor,
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
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(choice.$2),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  icon: Icon(
                    Icons.palette_outlined,
                    color: _parseColor(node?.color ?? '#7C8B5F'),
                  ),
                ),
                PopupMenuButton<MindMapNodeShape>(
                  tooltip: '共同節點形狀',
                  initialValue: widget.document.nodeShape,
                  onSelected: updateNodeShape,
                  itemBuilder: (context) => MindMapNodeShape.values
                      .map(
                        (shape) => PopupMenuItem(
                          value: shape,
                          child: Text(_nodeShapeLabel(shape)),
                        ),
                      )
                      .toList(),
                  icon: const Icon(Icons.category_outlined),
                ),
                IconButton(
                  tooltip: '刪除節點',
                  onPressed:
                      node == null || node.id == widget.document.rootNodeId
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
                const VerticalDivider(indent: 8, endIndent: 8),
                IconButton(
                  tooltip: '縮小畫布',
                  onPressed: () => zoomBy(0.8),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  tooltip: '放大畫布',
                  onPressed: () => zoomBy(1.25),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  tooltip: '顯示全部節點',
                  onPressed: fitCanvas,
                  icon: const Icon(Icons.fit_screen),
                ),
                IconButton(
                  tooltip: '置中選取節點',
                  onPressed: node == null ? null : () => centerNode(node),
                  icon: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '向右查看更多工具',
            onPressed: toolbarCanScrollRight
                ? () => scrollNodeToolbar(1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget buildOutline() {
    final colorScheme = Theme.of(context).colorScheme;
    final nodes = outlineNodes;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '大綱',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: '從大綱新增子節點',
                  onPressed: addChild,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              key: const ValueKey('mind-map-outline'),
              scrollController: outlineScrollController,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: nodes.length,
              onReorderItem: reorderOutline,
              itemBuilder: (context, index) {
                final entry = nodes[index];
                final item = entry.$1;
                final depth = entry.$2;
                final itemKey = outlineKeys.putIfAbsent(item.id, GlobalKey.new);
                final hasChildren = widget.document.nodes.any(
                  (candidate) => candidate.parentId == item.id,
                );
                return Material(
                  key: ValueKey('outline-${item.id}'),
                  color: selectedId == item.id
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  child: ListTile(
                    key: itemKey,
                    dense: true,
                    contentPadding: EdgeInsets.only(
                      left: 6 + depth * 18,
                      right: 4,
                    ),
                    leading: hasChildren
                        ? IconButton(
                            tooltip: item.expanded ? '收合子節點' : '展開子節點',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              item.expanded = !item.expanded;
                              setState(() {});
                              widget.onChanged(widget.document);
                            },
                            icon: Icon(
                              item.expanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                            ),
                          )
                        : const SizedBox(width: 40),
                    title: Text(
                      item.title.isEmpty ? '未命名節點' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.locked) const Icon(Icons.lock, size: 16),
                        if (!item.expanded)
                          const Icon(Icons.unfold_more, size: 16),
                        if (item.links.isNotEmpty)
                          const Icon(Icons.link, size: 16),
                        const Icon(Icons.drag_handle, size: 20),
                      ],
                    ),
                    onTap: () => selectFromOutline(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCanvas() {
    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      focusNode: canvasFocusNode,
      onKeyEvent: handleCanvasKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildNodeToolbar(),
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                canvasViewportSize = constraints.biggest;
                return Container(
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
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                canvasFocusNode.requestFocus();
                                setState(() {
                                  selectedId = null;
                                  selectedConnectionId = null;
                                });
                              },
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MindMapConnectionPainter(
                                document: widget.document,
                                visibleNodeIds: widget.document.nodes
                                    .where(isVisible)
                                    .map((node) => node.id)
                                    .toSet(),
                              ),
                            ),
                          ),
                          for (final item in widget.document.nodes.where(
                            isVisible,
                          ))
                            Positioned(
                              key: ValueKey(item.id),
                              left: item.x,
                              top: item.y,
                              width: mindMapNodeSize(
                                widget.document,
                                item,
                              ).width,
                              height: mindMapNodeSize(
                                widget.document,
                                item,
                              ).height,
                              child: MouseRegion(
                                cursor: item.locked
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.move,
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (_) {
                                    if (connectionSourceId != null) return;
                                    canvasFocusNode.requestFocus();
                                    setState(() {
                                      selectedId = item.id;
                                      selectedConnectionId = null;
                                      movingNodeId = item.locked
                                          ? null
                                          : item.id;
                                    });
                                    revealOutlineSelection();
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
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {},
                                    onDoubleTap: renameSelected,
                                    child: _MindMapNodeCard(
                                      node: item,
                                      selected: selectedId == item.id,
                                      level: mindMapNodeDepth(
                                        widget.document,
                                        item,
                                      ),
                                      shape: widget.document.nodeShape,
                                      isRoot:
                                          item.id == widget.document.rootNodeId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 620,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => setState(() => narrowViewIndex = 0),
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('大綱'),
                          style: TextButton.styleFrom(
                            backgroundColor: narrowViewIndex == 0
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => setState(() => narrowViewIndex = 1),
                          icon: const Icon(Icons.hub_outlined),
                          label: const Text('畫布'),
                          style: TextButton.styleFrom(
                            backgroundColor: narrowViewIndex == 1
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: IndexedStack(
                    index: narrowViewIndex,
                    children: [buildOutline(), buildCanvas()],
                  ),
                ),
              ],
            );
          }
          final maxOutline = math.min(420.0, constraints.maxWidth - 360);
          final resolvedOutline = outlineWidth.clamp(220.0, maxOutline);
          return Row(
            children: [
              SizedBox(width: resolvedOutline, child: buildOutline()),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(() {
                    outlineWidth = (outlineWidth + details.delta.dx).clamp(
                      220.0,
                      maxOutline,
                    );
                  }),
                  child: const SizedBox(width: 12),
                ),
              ),
              Expanded(child: buildCanvas()),
            ],
          );
        },
      ),
    );
  }
}

bool reorderMindMapOutlineNodes(
  MindMapDocument document,
  List<(MindMapNode, int)> visibleNodes,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex == newIndex ||
      oldIndex < 0 ||
      oldIndex >= visibleNodes.length ||
      newIndex < 0 ||
      newIndex >= visibleNodes.length) {
    return false;
  }
  final moving = visibleNodes[oldIndex].$1;
  final target = visibleNodes[newIndex].$1;
  if (moving.id == document.rootNodeId || moving.parentId != target.parentId) {
    return false;
  }
  document.nodes.remove(moving);
  final targetIndex = document.nodes.indexOf(target);
  document.nodes.insert(
    targetIndex < 0 ? document.nodes.length : targetIndex,
    moving,
  );
  return true;
}

int mindMapNodeDepth(MindMapDocument document, MindMapNode node) {
  var depth = 0;
  var current = node;
  final visited = <String>{node.id};
  while (current.parentId != null) {
    final parent = document.nodes
        .where((candidate) => candidate.id == current.parentId)
        .firstOrNull;
    if (parent == null || !visited.add(parent.id)) break;
    depth += 1;
    current = parent;
  }
  return depth;
}

Size mindMapNodeSize(MindMapDocument document, MindMapNode node) {
  final depth = mindMapNodeDepth(document, node);
  final titleLength = node.title.runes.length.clamp(1, 18);
  final minWidth = depth == 0
      ? 160.0
      : depth == 1
      ? 136.0
      : 112.0;
  final maxWidth = depth == 0
      ? 240.0
      : depth == 1
      ? 220.0
      : 196.0;
  final width = (70 + titleLength * (depth == 0 ? 10 : 8)).clamp(
    minWidth,
    maxWidth,
  );
  final height = depth == 0
      ? 88.0
      : depth == 1
      ? 72.0
      : 62.0;
  return Size(width.toDouble(), height);
}

String _nodeShapeLabel(MindMapNodeShape shape) => switch (shape) {
  MindMapNodeShape.roundedRectangle => '圓角矩形',
  MindMapNodeShape.rectangle => '矩形',
  MindMapNodeShape.ellipse => '橢圓',
};

class _MindMapNodeCard extends StatelessWidget {
  const _MindMapNodeCard({
    required this.node,
    required this.selected,
    required this.level,
    required this.shape,
    required this.isRoot,
  });

  final MindMapNode node;
  final bool selected;
  final int level;
  final MindMapNodeShape shape;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isRoot ? colorScheme.primary : _parseColor(node.color);
    final borderRadius = switch (shape) {
      MindMapNodeShape.roundedRectangle => BorderRadius.circular(10),
      MindMapNodeShape.rectangle => BorderRadius.zero,
      MindMapNodeShape.ellipse => BorderRadius.circular(999),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isRoot ? 0.2 : 0.15),
        border: Border.all(
          color: selected ? colorScheme.primary : color,
          width: selected ? 2.5 : 1.2,
        ),
        borderRadius: borderRadius,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title.isEmpty ? '未命名節點' : node.title,
                    maxLines: level == 0 ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: level == 0
                          ? 18
                          : level == 1
                          ? 16
                          : 14,
                      fontWeight: level <= 1
                          ? FontWeight.w800
                          : FontWeight.w700,
                    ),
                  ),
                  if (node.subtitle.isNotEmpty)
                    Text(
                      node.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (node.locked) const Icon(Icons.lock, size: 15),
                if (!node.expanded) const Icon(Icons.unfold_more, size: 15),
                if (node.links.isNotEmpty) const Icon(Icons.link, size: 15),
              ],
            ),
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
  });

  final MindMapDocument document;
  final Set<String> visibleNodeIds;

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
    final fromSize = mindMapNodeSize(document, from);
    final toSize = mindMapNodeSize(document, to);
    final start = Offset(
      from.x + fromSize.width / 2,
      from.y + fromSize.height / 2,
    );
    final end = Offset(to.x + toSize.width / 2, to.y + toSize.height / 2);
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
