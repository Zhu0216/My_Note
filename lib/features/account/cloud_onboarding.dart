import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/my_note_data.dart';
import '../../ui/app_store_scope.dart';
import 'account_controller.dart';

const cloudRecordCollections = <String>[
  'notes',
  'schedules',
  'subscriptions',
  'financeEntries',
  'savingsAccounts',
  'todos',
];

enum CloudConflictChoice { local, cloud, both }

class CloudRecord {
  const CloudRecord({
    required this.collection,
    required this.id,
    required this.data,
  });

  final String collection;
  final String id;
  final Map<String, dynamic> data;
  String get key => '$collection:$id';
}

class CloudSpaceSnapshot {
  const CloudSpaceSnapshot({required this.records, required this.settings});

  factory CloudSpaceSnapshot.fromLocal(Map<String, dynamic> local) {
    final records = <String, CloudRecord>{};
    for (final collection in cloudRecordCollections) {
      for (final value in readMapList(local[collection])) {
        final id = readString(value['id']);
        if (id.isEmpty) continue;
        final record = CloudRecord(
          collection: collection,
          id: id,
          data: cloneJsonMap(value),
        );
        records[record.key] = record;
      }
    }
    final settings = cloneJsonMap(local)..remove('_persistence');
    for (final collection in cloudRecordCollections) {
      settings.remove(collection);
    }
    return CloudSpaceSnapshot(records: records, settings: settings);
  }

  final Map<String, CloudRecord> records;
  final Map<String, dynamic> settings;
  bool get isEmpty => records.isEmpty && !_hasMeaningfulSettings(settings);

  Map<String, dynamic> toLocalData() {
    final result = cloneJsonMap(settings);
    for (final collection in cloudRecordCollections) {
      result[collection] = records.values
          .where((item) => item.collection == collection)
          .map((item) => cloneJsonMap(item.data))
          .toList(growable: false);
    }
    return result;
  }

  static bool _hasMeaningfulSettings(Map<String, dynamic> value) =>
      readMapList(value['noteFolders']).isNotEmpty ||
      readDouble(value['monthlyBudget']) != 18000 ||
      readStringList(value['collapsedHomeSections']).isNotEmpty ||
      readStringList(value['hiddenHomeSections']).isNotEmpty ||
      readStringList(value['hiddenUpcomingItems']).isNotEmpty ||
      value['homeAutoCollapseOnScroll'] == true;
}

class CloudMergePreview {
  const CloudMergePreview({
    required this.local,
    required this.cloud,
    required this.conflicts,
  });

  factory CloudMergePreview.compare(
    CloudSpaceSnapshot local,
    CloudSpaceSnapshot cloud,
  ) {
    final conflicts = <String>[];
    for (final key in local.records.keys.toSet().intersection(
      cloud.records.keys.toSet(),
    )) {
      if (_canonical(local.records[key]!.data) !=
          _canonical(cloud.records[key]!.data)) {
        conflicts.add(key);
      }
    }
    conflicts.sort();
    return CloudMergePreview(local: local, cloud: cloud, conflicts: conflicts);
  }

  final CloudSpaceSnapshot local;
  final CloudSpaceSnapshot cloud;
  final List<String> conflicts;

  CloudSpaceSnapshot merge(
    Map<String, CloudConflictChoice> choices, {
    String Function(String originalId)? createCopyId,
  }) {
    final idFactory =
        createCopyId ??
        (id) => '${id}_cloud_${DateTime.now().microsecondsSinceEpoch}';
    final merged = <String, CloudRecord>{...local.records};
    final remappedIds = <String, String>{};
    for (final key in conflicts) {
      if (choices[key] == CloudConflictChoice.both) {
        final cloudRecord = cloud.records[key]!;
        remappedIds[cloudRecord.id] = idFactory(cloudRecord.id);
      }
    }
    for (final entry in cloud.records.entries) {
      final localRecord = local.records[entry.key];
      if (localRecord == null) {
        merged[entry.key] = _remapRecord(entry.value, remappedIds);
        continue;
      }
      if (_canonical(localRecord.data) == _canonical(entry.value.data)) {
        continue;
      }
      switch (choices[entry.key] ?? CloudConflictChoice.local) {
        case CloudConflictChoice.local:
          break;
        case CloudConflictChoice.cloud:
          merged[entry.key] = _remapRecord(entry.value, remappedIds);
          break;
        case CloudConflictChoice.both:
          final duplicate = _remapRecord(entry.value, remappedIds);
          merged[duplicate.key] = duplicate;
          break;
      }
    }
    return CloudSpaceSnapshot(
      records: merged,
      settings: local.settings.isEmpty ? cloud.settings : local.settings,
    );
  }
}

class CloudSpaceRepository {
  CloudSpaceRepository([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _space(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('spaces')
      .doc('default');

  Future<CloudSpaceSnapshot> read(String uid) async {
    final space = _space(uid);
    final results = await Future.wait([
      space.get(),
      space.collection('records').get(),
    ]);
    final metadata = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final recordQuery = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final records = <String, CloudRecord>{};
    for (final document in recordQuery.docs) {
      final value = document.data();
      final collection = readString(value['collection']);
      final id = readString(value['recordId']);
      final payload = value['payload'];
      if (collection.isEmpty || id.isEmpty || payload is! Map) continue;
      final record = CloudRecord(
        collection: collection,
        id: id,
        data: Map<String, dynamic>.from(payload),
      );
      records[record.key] = record;
    }
    final settings = metadata.data()?['settings'];
    return CloudSpaceSnapshot(
      records: records,
      settings: settings is Map ? Map<String, dynamic>.from(settings) : {},
    );
  }

  Future<void> replace(String uid, CloudSpaceSnapshot snapshot) async {
    final space = _space(uid);
    final existing = await space.collection('records').get();
    final desiredDocumentIds = snapshot.records.values.map(_documentId).toSet();
    final operations = <void Function(WriteBatch)>[
      for (final document in existing.docs.where(
        (document) => !desiredDocumentIds.contains(document.id),
      ))
        (batch) => batch.delete(document.reference),
      for (final record in snapshot.records.values)
        (batch) =>
            batch.set(space.collection('records').doc(_documentId(record)), {
              'collection': record.collection,
              'recordId': record.id,
              'payload': record.data,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      (batch) => batch.set(space, {
        'schema': 'my_note.cloud.v1',
        'settings': snapshot.settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ];
    for (var offset = 0; offset < operations.length; offset += 400) {
      final batch = _firestore.batch();
      for (final operation in operations.skip(offset).take(400)) {
        operation(batch);
      }
      await batch.commit();
    }
  }

  String _documentId(CloudRecord record) =>
      base64Url.encode(utf8.encode(record.key)).replaceAll('=', '');
}

class CloudOnboardingPage extends StatefulWidget {
  const CloudOnboardingPage({super.key});

  @override
  State<CloudOnboardingPage> createState() => _CloudOnboardingPageState();
}

class _CloudOnboardingPageState extends State<CloudOnboardingPage> {
  final repository = CloudSpaceRepository();
  CloudMergePreview? preview;
  final choices = <String, CloudConflictChoice>{};
  String? error;
  bool busy = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (preview == null && busy) _load();
  }

  Future<void> _load() async {
    try {
      final account = AccountScope.of(context);
      final uid = account.user!.uid;
      final local = CloudSpaceSnapshot.fromLocal(
        AppStoreScope.read(context).toJson(),
      );
      final cloud = await repository.read(uid);
      if (!mounted) return;
      setState(() {
        preview = CloudMergePreview.compare(local, cloud);
        for (final key in preview!.conflicts) {
          choices[key] = CloudConflictChoice.local;
        }
        busy = false;
      });
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = '$exception';
          busy = false;
        });
      }
    }
  }

  Future<void> _apply(
    CloudSpaceSnapshot result, {
    required bool importLocal,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final store = AppStoreScope.read(context);
      final account = AccountScope.of(context);
      final bundle = LocalDataBundle(
        createdAt: DateTime.now(),
        data: result.toLocalData(),
      ).encode();
      LocalDataBundle.decode(bundle);
      await repository.replace(account.user!.uid, result);
      if (importLocal) await store.importBundle(bundle);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = '$exception';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = preview;
    return Scaffold(
      appBar: AppBar(title: const Text('設定首次同步')),
      body: busy || value == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '本機 ${value.local.records.length} 項 · 雲端 ${value.cloud.records.length} 項',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('登入不會自動傳輸資料。請確認這次要建立的單一雲端資料空間。'),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (value.conflicts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    '同 ID 衝突',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final key in value.conflicts)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(key),
                            SegmentedButton<CloudConflictChoice>(
                              segments: const [
                                ButtonSegment(
                                  value: CloudConflictChoice.local,
                                  label: Text('本機'),
                                ),
                                ButtonSegment(
                                  value: CloudConflictChoice.cloud,
                                  label: Text('雲端'),
                                ),
                                ButtonSegment(
                                  value: CloudConflictChoice.both,
                                  label: Text('兩者'),
                                ),
                              ],
                              selected: {choices[key]!},
                              onSelectionChanged: (selected) => setState(
                                () => choices[key] = selected.single,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final result = value.cloud.isEmpty
                              ? value.local
                              : value.local.isEmpty
                              ? value.cloud
                              : value.merge(choices);
                          await _apply(
                            result,
                            importLocal: !value.cloud.isEmpty,
                          );
                        },
                  child: Text(
                    value.cloud.isEmpty && value.local.isEmpty
                        ? '建立空白同步空間'
                        : value.cloud.isEmpty
                        ? '上傳本機資料'
                        : value.local.isEmpty
                        ? '下載雲端資料'
                        : '依選擇合併',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('保留本機獨立資料'),
                ),
              ],
            ),
    );
  }
}

CloudRecord _remapRecord(CloudRecord source, Map<String, String> ids) {
  final data = _remapValue(source.data, ids) as Map<String, dynamic>;
  final id = ids[source.id] ?? source.id;
  data['id'] = id;
  return CloudRecord(collection: source.collection, id: id, data: data);
}

Object? _remapValue(Object? value, Map<String, String> ids) {
  if (value is String) return ids[value] ?? value;
  if (value is List) {
    return value.map((item) => _remapValue(item, ids)).toList();
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _remapValue(entry.value, ids),
    };
  }
  return value;
}

String _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}
