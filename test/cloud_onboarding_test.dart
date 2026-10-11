import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/account/cloud_onboarding.dart';

void main() {
  CloudRecord note(String id, String title, {String? link}) => CloudRecord(
    collection: 'notes',
    id: id,
    data: {
      'id': id,
      'title': title,
      if (link != null)
        'links': [
          {'type': 'note', 'targetId': link},
        ],
    },
  );

  test('cloud merge identifies only same-id different-content conflicts', () {
    final local = CloudSpaceSnapshot(
      records: {
        'notes:n1': note('n1', 'local'),
        'notes:n2': note('n2', 'same'),
      },
      settings: const {},
    );
    final cloud = CloudSpaceSnapshot(
      records: {
        'notes:n1': note('n1', 'cloud'),
        'notes:n2': note('n2', 'same'),
        'notes:n3': note('n3', 'cloud only'),
      },
      settings: const {},
    );

    final preview = CloudMergePreview.compare(local, cloud);

    expect(preview.conflicts, ['notes:n1']);
    expect(preview.merge(const {}).records['notes:n1']!.data['title'], 'local');
    expect(preview.merge(const {}).records, contains('notes:n3'));
  });

  test('keeping both assigns a new id and remaps cloud references', () {
    final local = CloudSpaceSnapshot(
      records: {'notes:n1': note('n1', 'local')},
      settings: const {},
    );
    final cloud = CloudSpaceSnapshot(
      records: {
        'notes:n1': note('n1', 'cloud'),
        'notes:n2': note('n2', 'points to cloud conflict', link: 'n1'),
      },
      settings: const {},
    );
    final preview = CloudMergePreview.compare(local, cloud);

    final merged = preview.merge(const {
      'notes:n1': CloudConflictChoice.both,
    }, createCopyId: (_) => 'n1-cloud-copy');

    expect(merged.records['notes:n1']!.data['title'], 'local');
    expect(merged.records['notes:n1-cloud-copy']!.data['title'], 'cloud');
    final links = merged.records['notes:n2']!.data['links'] as List;
    expect((links.single as Map)['targetId'], 'n1-cloud-copy');
  });
}
