part of 'my_note_data.dart';

/// A stable reference to another local record. Links are intentionally
/// lightweight: v1 needs navigable context, not a graph renderer.
enum RelatedItemType {
  note,
  plan,
  mindMap,
  lifeProject,
  todo,
  schedule,
  finance,
  subscription,
  account,
}

class RelatedItemLink {
  const RelatedItemLink({required this.type, required this.targetId});

  final RelatedItemType type;
  final String targetId;

  Map<String, dynamic> toJson() => {'type': type.name, 'targetId': targetId};

  factory RelatedItemLink.fromJson(Map<String, dynamic> data) =>
      RelatedItemLink(
        type: readEnum(
          RelatedItemType.values,
          data['type'],
          RelatedItemType.note,
        ),
        targetId: readString(data['targetId']),
      );
}

List<RelatedItemLink> normalizeRelatedItemLinks(
  Iterable<RelatedItemLink>? links,
) {
  final unique = <String, RelatedItemLink>{};
  for (final link in links ?? const <RelatedItemLink>[]) {
    if (link.targetId.trim().isEmpty) continue;
    unique.putIfAbsent('${link.type.name}:${link.targetId}', () => link);
  }
  return unique.values.toList();
}

List<RelatedItemLink> readRelatedItemLinks(Object? value) =>
    normalizeRelatedItemLinks(readMapList(value).map(RelatedItemLink.fromJson));

enum PlanNodeType { phase, task }

class PlanNode {
  PlanNode({
    required this.id,
    required this.title,
    required this.type,
    this.parentId,
    this.completed = false,
    this.dueDate,
    this.priority = 0,
    this.weight = 1,
    this.linkedTodoId,
    this.linkedScheduleId,
    this.showOnHome = false,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String title;
  PlanNodeType type;
  String? parentId;
  bool completed;
  DateTime? dueDate;
  int priority;
  double weight;
  String? linkedTodoId;
  String? linkedScheduleId;
  bool showOnHome;
  List<RelatedItemLink> links;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'parentId': parentId,
    'completed': completed,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority,
    'weight': weight,
    'linkedTodoId': linkedTodoId,
    'linkedScheduleId': linkedScheduleId,
    'showOnHome': showOnHome,
    'links': links.map((item) => item.toJson()).toList(),
  };

  factory PlanNode.fromJson(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final type = readEnum(PlanNodeType.values, data['type'], PlanNodeType.task);
    return PlanNode(
      id: readString(data['id'], fallback: fallbackId),
      title: readString(data['title']),
      type: type,
      parentId: readOptionalString(data['parentId']),
      completed: data['completed'] == true || data['done'] == true,
      dueDate: readOptionalDate(data['dueDate']),
      priority: readInt(data['priority']),
      weight: readDouble(data['weight'], fallback: 1).clamp(0.01, 1000),
      linkedTodoId: readOptionalString(data['linkedTodoId']),
      linkedScheduleId: readOptionalString(data['linkedScheduleId']),
      showOnHome: data['showOnHome'] == true,
      links: readRelatedItemLinks(data['links']),
    );
  }
}

class PlanDocument {
  PlanDocument({
    List<PlanNode>? nodes,
    this.goal = '',
    this.startDate,
    this.dueDate,
    this.spentHours = 0,
    this.notes = '',
  }) : nodes = nodes ?? <PlanNode>[];

  static const schema = 'plan.v2';
  final List<PlanNode> nodes;
  String goal;
  DateTime? startDate;
  DateTime? dueDate;
  double spentHours;
  String notes;

  List<PlanNode> childrenOf(String? parentId) =>
      nodes.where((node) => node.parentId == parentId).toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  double progressOf(String? parentId) {
    final children = childrenOf(parentId);
    if (children.isEmpty) return 0;
    final totalWeight = children.fold<double>(
      0,
      (sum, node) => sum + node.weight,
    );
    if (totalWeight <= 0) return 0;
    final earned = children.fold<double>(0, (sum, node) {
      final progress = node.type == PlanNodeType.task
          ? (node.completed ? 1.0 : 0.0)
          : progressOf(node.id);
      return sum + (progress * node.weight);
    });
    return (earned / totalWeight).clamp(0, 1);
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'goal': goal,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'spentHours': spentHours,
    'notes': notes,
  };

  factory PlanDocument.fromJson(Map<String, dynamic> data) {
    final nodes = readMapList(data['nodes']).indexed
        .map(
          (entry) =>
              PlanNode.fromJson(entry.$2, fallbackId: 'plan-node-${entry.$1}'),
        )
        .toList();
    if (nodes.isEmpty) {
      // v1 stored a free-text phase plus a flat task list.
      final phase = readString(data['phase']);
      final legacyParentId = phase.isEmpty ? null : 'legacy-phase';
      if (phase.isNotEmpty) {
        nodes.add(
          PlanNode(id: legacyParentId!, title: phase, type: PlanNodeType.phase),
        );
      }
      for (final entry in readMapList(data['tasks']).indexed) {
        nodes.add(
          PlanNode(
            id: 'legacy-task-${entry.$1}',
            title: readString(entry.$2['title']),
            type: PlanNodeType.task,
            parentId: legacyParentId,
            completed: entry.$2['done'] == true,
          ),
        );
      }
    }
    return PlanDocument(
      nodes: nodes,
      goal: readString(data['goal']),
      startDate: readOptionalDate(data['startDate']),
      dueDate: readOptionalDate(data['dueDate']),
      spentHours: readDouble(data['spentHours']),
      notes: readString(data['notes']),
    );
  }
}

bool isLegacyPlanDocument(Map<String, dynamic> data) =>
    data['schema'] != PlanDocument.schema;

Map<String, dynamic> migratePlanDocumentForEditing(Map<String, dynamic> data) =>
    PlanDocument.fromJson(data).toJson();

class MindMapNode {
  MindMapNode({
    required this.id,
    required this.title,
    this.parentId,
    this.x = 0,
    this.y = 0,
    this.color = '#7C8B5F',
    this.expanded = true,
    this.locked = false,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String title;
  String? parentId;
  double x;
  double y;
  String color;
  bool expanded;
  bool locked;
  List<RelatedItemLink> links;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'parentId': parentId,
    'x': x,
    'y': y,
    'color': color,
    'expanded': expanded,
    'locked': locked,
    'links': links.map((item) => item.toJson()).toList(),
  };

  factory MindMapNode.fromJson(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) => MindMapNode(
    id: readString(data['id'], fallback: fallbackId),
    title: readString(data['title']),
    parentId: readOptionalString(data['parentId']),
    x: readDouble(data['x']),
    y: readDouble(data['y']),
    color: readString(data['color'], fallback: '#7C8B5F'),
    expanded: data['expanded'] != false,
    locked: data['locked'] == true,
    links: readRelatedItemLinks(data['links']),
  );
}

enum MindMapLineStyle { solid, dashed }

class MindMapConnection {
  MindMapConnection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.color = '#7C8B5F',
    this.style = MindMapLineStyle.solid,
    this.directed = false,
  });

  final String id;
  String fromNodeId;
  String toNodeId;
  String color;
  MindMapLineStyle style;
  bool directed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromNodeId': fromNodeId,
    'toNodeId': toNodeId,
    'color': color,
    'style': style.name,
    'directed': directed,
  };

  factory MindMapConnection.fromJson(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) => MindMapConnection(
    id: readString(data['id'], fallback: fallbackId),
    fromNodeId: readString(data['fromNodeId']),
    toNodeId: readString(data['toNodeId']),
    color: readString(data['color'], fallback: '#7C8B5F'),
    style: readEnum(
      MindMapLineStyle.values,
      data['style'],
      MindMapLineStyle.solid,
    ),
    directed: data['directed'] == true,
  );
}

class MindMapDocument {
  MindMapDocument({
    required this.rootNodeId,
    List<MindMapNode>? nodes,
    List<MindMapConnection>? connections,
  }) : nodes = nodes ?? <MindMapNode>[],
       connections = connections ?? <MindMapConnection>[];

  static const schema = 'mind_map.v2';
  String rootNodeId;
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'rootNodeId': rootNodeId,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'connections': connections.map((line) => line.toJson()).toList(),
  };

  factory MindMapDocument.fromJson(Map<String, dynamic> data) {
    final nodes = readMapList(data['nodes']).indexed
        .map(
          (entry) => MindMapNode.fromJson(
            entry.$2,
            fallbackId: 'mind-node-${entry.$1}',
          ),
        )
        .toList();
    if (nodes.isEmpty) {
      nodes.add(MindMapNode(id: 'mind-root', title: readString(data['topic'])));
    }
    return MindMapDocument(
      rootNodeId: readString(data['rootNodeId'], fallback: nodes.first.id),
      nodes: nodes,
      connections: readMapList(data['connections']).indexed
          .map(
            (entry) => MindMapConnection.fromJson(
              entry.$2,
              fallbackId: 'mind-line-${entry.$1}',
            ),
          )
          .toList(),
    );
  }
}

enum LifeItemDisplayMode { money, progress }

enum LifeProjectStatus { active, completed }

class LifeProjectItem {
  LifeProjectItem({
    required this.id,
    required this.name,
    this.displayMode = LifeItemDisplayMode.money,
    this.targetAmount = 0,
    this.manualCurrentAmount = 0,
    this.progress = 0,
    this.completed = false,
    this.weight = 1,
    this.sortOrder = 0,
    List<String>? accountIds,
    List<RelatedItemLink>? links,
  }) : accountIds = accountIds ?? <String>[],
       links = normalizeRelatedItemLinks(links);

  final String id;
  String name;
  LifeItemDisplayMode displayMode;
  double targetAmount;
  double manualCurrentAmount;
  double progress;
  bool completed;
  double weight;
  int sortOrder;
  List<String> accountIds;
  List<RelatedItemLink> links;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'displayMode': displayMode.name,
    'targetAmount': targetAmount,
    'manualCurrentAmount': manualCurrentAmount,
    'progress': progress,
    'completed': completed,
    'weight': weight,
    'sortOrder': sortOrder,
    'accountIds': accountIds,
    'links': links.map((item) => item.toJson()).toList(),
  };

  factory LifeProjectItem.fromJson(
    Map<String, dynamic> data, {
    required String fallbackId,
    required int fallbackOrder,
  }) => LifeProjectItem(
    id: readString(data['id'], fallback: fallbackId),
    name: readString(data['name']),
    displayMode: readEnum(
      LifeItemDisplayMode.values,
      data['displayMode'],
      LifeItemDisplayMode.money,
    ),
    targetAmount: readDouble(data['targetAmount']),
    manualCurrentAmount: readDouble(
      data['manualCurrentAmount'],
      fallback: readDouble(data['currentAmount']),
    ),
    progress: readDouble(data['progress']).clamp(0, 1),
    completed: data['completed'] == true,
    weight: readDouble(data['weight'], fallback: 1).clamp(0.01, 1000),
    sortOrder: readInt(data['sortOrder'], fallback: fallbackOrder),
    accountIds: readStringList(data['accountIds']),
    links: readRelatedItemLinks(data['links']),
  );
}

class LifeProjectDocument {
  LifeProjectDocument({
    this.status = LifeProjectStatus.active,
    List<LifeProjectItem>? items,
  }) : items = items ?? <LifeProjectItem>[];

  static const schema = 'life_sheet.v2';
  LifeProjectStatus status;
  final List<LifeProjectItem> items;

  double get weightedProgress {
    if (items.isEmpty) return 0;
    final totalWeight = items.fold<double>(0, (sum, item) => sum + item.weight);
    if (totalWeight <= 0) return 0;
    return (items.fold<double>(0, (sum, item) {
              final progress = item.displayMode == LifeItemDisplayMode.money
                  ? (item.targetAmount <= 0
                        ? 0
                        : item.manualCurrentAmount / item.targetAmount)
                  : item.progress;
              return sum + progress.clamp(0, 1) * item.weight;
            }) /
            totalWeight)
        .clamp(0, 1);
  }

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'status': status.name,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory LifeProjectDocument.fromJson(Map<String, dynamic> data) =>
      LifeProjectDocument(
        status: readEnum(
          LifeProjectStatus.values,
          data['status'],
          LifeProjectStatus.active,
        ),
        items: readMapList(data['items']).indexed
            .map(
              (entry) => LifeProjectItem.fromJson(
                entry.$2,
                fallbackId: 'life-item-${entry.$1}',
                fallbackOrder: entry.$1,
              ),
            )
            .toList(),
      );
}

String? readOptionalString(Object? value) {
  final text = readString(value).trim();
  return text.isEmpty ? null : text;
}
