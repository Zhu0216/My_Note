import 'my_note_data.dart';

class RelatedItemDescriptor {
  const RelatedItemDescriptor({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final RelatedItemType type;
  final String id;
  final String title;
  final String subtitle;

  RelatedItemLink get link => RelatedItemLink(type: type, targetId: id);
  String get key => '${type.name}:$id';
}

extension AppStoreRelatedItemIndex on AppStore {
  List<RelatedItemDescriptor> relatedItemCandidates({
    String query = '',
    RelatedItemLink? exclude,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final excludedKey = exclude == null
        ? null
        : '${exclude.type.name}:${exclude.targetId}';
    final items = _allRelatedItemRecords()
        .map((record) => record.descriptor)
        .where((item) => item.key != excludedKey)
        .where(
          (item) =>
              normalizedQuery.isEmpty ||
              item.title.toLowerCase().contains(normalizedQuery) ||
              item.subtitle.toLowerCase().contains(normalizedQuery),
        )
        .toList();
    items.sort((left, right) {
      final typeOrder = left.type.index.compareTo(right.type.index);
      return typeOrder != 0 ? typeOrder : left.title.compareTo(right.title);
    });
    return items;
  }

  RelatedItemDescriptor? describeRelatedItem(RelatedItemLink link) {
    final key = '${link.type.name}:${link.targetId}';
    for (final record in _allRelatedItemRecords()) {
      if (record.descriptor.key == key) {
        return record.descriptor;
      }
    }
    return null;
  }

  List<RelatedItemDescriptor> reverseLinksTo(RelatedItemLink target) {
    final targetKey = '${target.type.name}:${target.targetId}';
    return _allRelatedItemRecords()
        .where(
          (record) => record.links.any(
            (link) => '${link.type.name}:${link.targetId}' == targetKey,
          ),
        )
        .map((record) => record.descriptor)
        .toList();
  }

  Iterable<_RelatedItemRecord> _allRelatedItemRecords() sync* {
    for (final note in visibleNotes) {
      final type = switch (note.templateType) {
        NoteTemplateType.general => RelatedItemType.note,
        NoteTemplateType.plan => RelatedItemType.plan,
        NoteTemplateType.mindMap => RelatedItemType.mindMap,
        NoteTemplateType.lifeSheet => RelatedItemType.lifeProject,
      };
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: type,
          id: note.id,
          title: note.title,
          subtitle: note.category.isEmpty ? '未分類' : note.category,
        ),
        note.links,
      );
    }
    for (final todo in todos) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.todo,
          id: todo.id,
          title: todo.title,
          subtitle: todo.done ? '已完成' : '待辦事項',
        ),
        todo.links,
      );
    }
    for (final schedule in schedules) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.schedule,
          id: schedule.id,
          title: schedule.title,
          subtitle: schedule.location,
        ),
        schedule.links,
      );
    }
    for (final entry in financeEntries) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.finance,
          id: entry.id,
          title: entry.title,
          subtitle: entry.account,
        ),
        entry.links,
      );
    }
    for (final subscription in subscriptions) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.subscription,
          id: subscription.id,
          title: subscription.name,
          subtitle: subscription.category,
        ),
        subscription.links,
      );
    }
    for (final account in savingsAccounts) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.account,
          id: account.id,
          title: account.name,
          subtitle: '存餘帳戶',
        ),
        account.links,
      );
    }
  }
}

class _RelatedItemRecord {
  const _RelatedItemRecord(this.descriptor, this.links);

  final RelatedItemDescriptor descriptor;
  final List<RelatedItemLink> links;
}
