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

class HomeSearchResult {
  const HomeSearchResult({
    required this.item,
    required this.supportingText,
    required this.tags,
    required this.score,
    required this.modifiedAt,
  });

  final RelatedItemDescriptor item;
  final String supportingText;
  final List<String> tags;
  final int score;
  final DateTime modifiedAt;
}

extension AppStoreRelatedItemIndex on AppStore {
  List<HomeSearchResult> homeSearchResults(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (terms.isEmpty) return const [];

    final records = _allRelatedItemRecords().toList(growable: false);
    final descriptors = {
      for (final record in records) record.descriptor.key: record.descriptor,
    };
    final results = <HomeSearchResult>[];
    for (final record in records) {
      final title = record.descriptor.title.toLowerCase();
      final tags = record.searchTags.map((tag) => tag.toLowerCase()).toList();
      final body = record.searchBody.toLowerCase();
      final relatedText = record.links
          .map(
            (link) =>
                descriptors['${link.type.name}:${link.targetId}']?.title ?? '',
          )
          .join(' ')
          .toLowerCase();
      var score = 0;
      var matchedTerms = 0;
      for (final term in terms) {
        var termScore = 0;
        if (title == term) {
          termScore = 1000;
        } else if (title.contains(term)) {
          termScore = 600;
        }
        for (final tag in tags) {
          if (tag == term) {
            termScore = termScore < 450 ? 450 : termScore;
          } else if (tag.contains(term) && termScore < 350) {
            termScore = 350;
          }
        }
        if (body.contains(term) && termScore < 150) termScore = 150;
        if (relatedText.contains(term) && termScore < 75) termScore = 75;
        if (termScore > 0) {
          score += termScore;
          matchedTerms++;
        }
      }
      if (score == 0) continue;
      score += matchedTerms * 20;
      results.add(
        HomeSearchResult(
          item: record.descriptor,
          supportingText: _searchSupportingText(record, terms, descriptors),
          tags: record.searchTags,
          score: score,
          modifiedAt: record.modifiedAt,
        ),
      );
    }
    results.sort((left, right) {
      final relevance = right.score.compareTo(left.score);
      if (relevance != 0) return relevance;
      final modified = right.modifiedAt.compareTo(left.modifiedAt);
      if (modified != 0) return modified;
      return left.item.title.compareTo(right.item.title);
    });
    return results;
  }

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

  List<RelatedItemDescriptor> relatedItemsFrom(RelatedItemLink source) {
    final sourceKey = '${source.type.name}:${source.targetId}';
    for (final record in _allRelatedItemRecords()) {
      if (record.descriptor.key != sourceKey) {
        continue;
      }
      return record.links
          .map(describeRelatedItem)
          .whereType<RelatedItemDescriptor>()
          .toList();
    }
    return const [];
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
        normalizeRelatedItemLinks([
          ...note.links,
          ..._embeddedNoteLinks(note, notes),
        ]),
        searchTags: [
          ...note.tags,
          if (note.category.trim().isNotEmpty) note.category,
        ],
        searchBody: _noteSearchBody(note),
        modifiedAt: note.updatedAt,
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
        searchBody: [
          if (todo.dueDate != null) todo.dueDate!.toIso8601String(),
          todo.done ? '已完成' : '待辦事項',
        ].join(' '),
        modifiedAt: todo.completedAt ?? todo.dueDate,
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
        searchBody: '${schedule.location} ${schedule.notes}',
        modifiedAt: schedule.start,
      );
    }
    for (final entry in financeEntries) {
      yield _RelatedItemRecord(
        RelatedItemDescriptor(
          type: RelatedItemType.finance,
          id: entry.id,
          title: entry.title,
          subtitle:
              savingsAccounts
                  .where((account) => account.id == entry.accountId)
                  .map((account) => account.name)
                  .firstOrNull ??
              '未指定帳戶',
        ),
        entry.links,
        searchTags: [if (entry.category.isNotEmpty) entry.category],
        searchBody: '${entry.note} ${entry.amount}',
        modifiedAt: entry.date,
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
        searchTags: [
          if (subscription.category.isNotEmpty) subscription.category,
        ],
        searchBody: '${subscription.paymentMethod} ${subscription.amount}',
        modifiedAt: subscription.nextPaymentDate,
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
        searchBody: '${account.openingBalance}',
      );
    }
  }
}

List<RelatedItemLink> _embeddedNoteLinks(
  NoteItem note,
  Iterable<NoteItem> allNotes,
) {
  final richText = readStringMap(note.templateData['richText']);
  final spans = readMapList(richText['spans']);
  final links = <RelatedItemLink>[];
  for (final span in spans) {
    final attributes = readStringMap(span['attributes']);
    if (attributes['embedType'] != 'noteReference') continue;
    final targetId = readString(attributes['embedId']);
    final target = allNotes.where((item) => item.id == targetId).firstOrNull;
    if (target == null) continue;
    links.add(
      RelatedItemLink(
        type: switch (target.templateType) {
          NoteTemplateType.general => RelatedItemType.note,
          NoteTemplateType.plan => RelatedItemType.plan,
          NoteTemplateType.mindMap => RelatedItemType.mindMap,
          NoteTemplateType.lifeSheet => RelatedItemType.lifeProject,
        },
        targetId: targetId,
      ),
    );
  }
  return links;
}

class _RelatedItemRecord {
  _RelatedItemRecord(
    this.descriptor,
    this.links, {
    this.searchTags = const [],
    this.searchBody = '',
    DateTime? modifiedAt,
  }) : modifiedAt = modifiedAt ?? _searchEpoch;

  final RelatedItemDescriptor descriptor;
  final List<RelatedItemLink> links;
  final List<String> searchTags;
  final String searchBody;
  final DateTime modifiedAt;
}

final DateTime _searchEpoch = DateTime.fromMillisecondsSinceEpoch(0);

String _noteSearchBody(NoteItem note) {
  final values = <String>[note.body];
  switch (note.templateType) {
    case NoteTemplateType.general:
      break;
    case NoteTemplateType.plan:
      final document = PlanDocument.fromJson(note.templateData);
      values
        ..add(document.goal)
        ..add(document.notes)
        ..addAll(document.nodes.map((node) => node.title));
    case NoteTemplateType.mindMap:
      final document = MindMapDocument.fromJson(note.templateData);
      for (final node in document.nodes) {
        values.addAll([node.title, node.subtitle, node.description]);
      }
    case NoteTemplateType.lifeSheet:
      final document = LifeProjectDocument.fromJson(note.templateData);
      values
        ..add(document.notes)
        ..addAll(document.items.map((item) => item.name));
  }
  values.addAll(
    note.attachments.map((attachment) => readString(attachment['name'])),
  );
  return values.where((value) => value.trim().isNotEmpty).join(' ');
}

String _searchSupportingText(
  _RelatedItemRecord record,
  List<String> terms,
  Map<String, RelatedItemDescriptor> descriptors,
) {
  final matchingTags = record.searchTags
      .where((tag) => terms.any((term) => tag.toLowerCase().contains(term)))
      .toList(growable: false);
  if (matchingTags.isNotEmpty) {
    return matchingTags.map((tag) => '#$tag').join(' ');
  }
  final body = record.searchBody.trim();
  final bodyLower = body.toLowerCase();
  var matchAt = -1;
  for (final term in terms) {
    final index = bodyLower.indexOf(term);
    if (index >= 0 && (matchAt < 0 || index < matchAt)) matchAt = index;
  }
  if (matchAt >= 0) {
    final start = (matchAt - 18).clamp(0, body.length).toInt();
    final end = (matchAt + 54).clamp(start, body.length).toInt();
    return '${start > 0 ? '…' : ''}${body.substring(start, end)}${end < body.length ? '…' : ''}';
  }
  final related = record.links
      .map((link) => descriptors['${link.type.name}:${link.targetId}']?.title)
      .whereType<String>()
      .where((title) => terms.any((term) => title.toLowerCase().contains(term)))
      .toList(growable: false);
  if (related.isNotEmpty) return '關聯：${related.join('、')}';
  return record.descriptor.subtitle;
}
