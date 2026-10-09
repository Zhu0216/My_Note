import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/data/my_note_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAttachmentBlobStore implements AttachmentBlobStore {
  @override
  Future<bool> contains(String id) async => false;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Set<String>> listIds() async => <String>{};

  @override
  Future<String> put(Uint8List bytes) =>
      Future<String>.error(StateError('write failed'));

  @override
  Future<Uint8List?> read(String id) async => null;
}

NoteItem _noteWithAttachment(Map<String, dynamic> attachment) => NoteItem(
  id: 'note-with-attachment',
  title: '附件測試',
  body: '內容',
  category: '',
  tags: const [],
  createdAt: DateTime(2026, 10, 10),
  updatedAt: DateTime(2026, 10, 10),
  attachments: [attachment],
);

void main() {
  test('memory blob store deduplicates content by SHA-256', () async {
    final store = MemoryAttachmentBlobStore();
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final first = await store.put(bytes);
    final second = await store.put(Uint8List.fromList(bytes));

    expect(second, first);
    expect(await store.listIds(), {first});
    expect(await store.read(first), bytes);
  });

  test('attachment capacity enforces 25 MB, 100 MB, and 125 MB rules', () {
    expect(
      () => validateAttachmentCapacity(
        currentBytes: 0,
        newAttachmentBytes: maxAttachmentBytes + 1,
      ),
      throwsA(isA<AttachmentLimitException>()),
    );
    expect(
      () => validateAttachmentCapacity(
        currentBytes: attachmentWarningBoundaryBytes,
        newAttachmentBytes: maxAttachmentBytes,
      ),
      returnsNormally,
    );
    expect(
      () => validateAttachmentCapacity(
        currentBytes: attachmentWarningBoundaryBytes + 1,
        newAttachmentBytes: 1,
      ),
      throwsA(isA<AttachmentLimitException>()),
    );
    expect(
      () => validateAttachmentCapacity(
        currentBytes: maxNoteAttachmentBytes - 1,
        newAttachmentBytes: 2,
      ),
      throwsA(isA<AttachmentLimitException>()),
    );
  });

  test(
    'legacy Base64 attachment migrates atomically to blob metadata',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('portable attachment'));
      final source = AppStore.seeded(persistenceLocked: true)
        ..upsertNote(
          _noteWithAttachment({
            'id': 'legacy-attachment',
            'name': 'legacy.txt',
            'mimeType': 'text/plain',
            'size': bytes.length,
            'bytesBase64': base64Encode(bytes),
          }),
        );
      final legacyRaw = jsonEncode(source.toJson());
      source.dispose();
      SharedPreferences.setMockInitialValues({'my_note_local_v1': legacyRaw});
      final blobs = MemoryAttachmentBlobStore();

      final migrated = await AppStore.load(attachmentBlobStore: blobs);
      try {
        final attachment = migrated.notes.single.attachments.single;
        final blobId = attachment['blobId'] as String;
        expect(attachment, isNot(contains('bytesBase64')));
        expect(attachment['size'], bytes.length);
        expect(await blobs.read(blobId), bytes);

        final prefs = await SharedPreferences.getInstance();
        final persisted = prefs.getString('my_note_local_v1')!;
        expect(persisted, isNot(contains(base64Encode(bytes))));
        expect(persisted, contains(blobId));
      } finally {
        migrated.dispose();
      }
    },
  );

  test('portable export includes payload unless explicitly excluded', () async {
    SharedPreferences.setMockInitialValues({});
    final blobs = MemoryAttachmentBlobStore();
    final store = AppStore.seeded(
      persistenceLocked: true,
      attachmentBlobStore: blobs,
    );
    final bytes = Uint8List.fromList([9, 8, 7]);
    final attachment = await store.createAttachmentMetadata(
      existingAttachments: const [],
      name: 'sample.bin',
      bytes: bytes,
    );
    store.upsertNote(_noteWithAttachment(attachment));

    final included = jsonDecode(await store.exportBundle()) as Map;
    final includedAttachment =
        ((included['data'] as Map)['notes'] as List).first['attachments'].first
            as Map;
    expect(includedAttachment['bytesBase64'], base64Encode(bytes));
    expect(includedAttachment['payloadIncluded'], isTrue);

    final excluded =
        jsonDecode(await store.exportBundle(includeAttachments: false)) as Map;
    final excludedAttachment =
        ((excluded['data'] as Map)['notes'] as List).first['attachments'].first
            as Map;
    expect(excludedAttachment, isNot(contains('bytesBase64')));
    expect(excludedAttachment['payloadIncluded'], isFalse);
    store.dispose();
  });

  test('garbage collection keeps blobs referenced by backup history', () async {
    SharedPreferences.setMockInitialValues({});
    final blobs = MemoryAttachmentBlobStore();
    final store = await AppStore.load(attachmentBlobStore: blobs);
    final attachment = await store.createAttachmentMetadata(
      existingAttachments: const [],
      name: 'recoverable.bin',
      bytes: Uint8List.fromList([4, 5, 6]),
    );
    final blobId = attachment['blobId'] as String;
    store.upsertNote(_noteWithAttachment(attachment));
    await store.flushPersistence();

    store.permanentlyDeleteNotesById({'note-with-attachment'});
    await store.flushPersistence();

    expect(await blobs.contains(blobId), isTrue);
    expect(await store.recoverySnapshots(), isNotEmpty);
    store.dispose();
  });

  test(
    'failed legacy payload migration leaves current data unchanged',
    () async {
      final target =
          AppStore.seeded(
            persistenceLocked: true,
            attachmentBlobStore: _FailingAttachmentBlobStore(),
          )..upsertNote(
            NoteItem(
              id: 'kept',
              title: '保留內容',
              body: '不應被匯入覆蓋',
              category: '',
              tags: const [],
              createdAt: DateTime(2026, 10, 10),
              updatedAt: DateTime(2026, 10, 10),
            ),
          );
      final source = AppStore.seeded(persistenceLocked: true)
        ..upsertNote(
          _noteWithAttachment({
            'id': 'legacy',
            'name': 'cannot-write.txt',
            'size': 3,
            'bytesBase64': base64Encode([1, 2, 3]),
          }),
        );
      final bundle = await source.exportBundle();

      await expectLater(target.importBundle(bundle), throwsFormatException);
      expect(target.notes.single.id, 'kept');
      expect(target.notes.single.title, '保留內容');
      source.dispose();
      target.dispose();
    },
  );

  test(
    'import rejects corrupt attachment payload before replacing data',
    () async {
      final store = AppStore.seeded(persistenceLocked: true)
        ..upsertNote(
          NoteItem(
            id: 'kept',
            title: '原有筆記',
            body: '保留',
            category: '',
            tags: const [],
            createdAt: DateTime(2026, 10, 10),
            updatedAt: DateTime(2026, 10, 10),
          ),
        );
      final data = store.toJson();
      (data['notes'] as List).first['attachments'] = [
        {
          'id': 'broken',
          'name': 'broken.bin',
          'size': 4,
          'bytesBase64': base64Encode([1, 2, 3]),
        },
      ];
      final bundle = jsonEncode({
        'schema': 'my_note.local_export.v1',
        'createdAt': DateTime(2026, 10, 10).toIso8601String(),
        'data': data,
      });

      await expectLater(store.importBundle(bundle), throwsFormatException);
      expect(store.notes.single.title, '原有筆記');
      store.dispose();
    },
  );
}
