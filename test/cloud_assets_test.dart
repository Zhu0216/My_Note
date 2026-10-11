import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/account/cloud_assets.dart';
import 'package:my_note/features/account/cloud_onboarding.dart';
import 'package:my_note/main.dart';

void main() {
  test('cloud assets upload by hash and restore complete payloads', () async {
    final store = AppStore.seeded();
    final attachmentBytes = Uint8List.fromList([1, 2, 3, 4]);
    final imageBytes = Uint8List.fromList([5, 6, 7]);
    final coverBytes = Uint8List.fromList([8, 9]);
    final attachment = await store.createAttachmentMetadata(
      existingAttachments: const [],
      name: 'sample.bin',
      bytes: attachmentBytes,
      mimeType: 'application/octet-stream',
    );
    final snapshot = CloudSpaceSnapshot(
      records: {
        'notes:n1': CloudRecord(
          collection: 'notes',
          id: 'n1',
          data: {
            'id': 'n1',
            'title': 'assets',
            'images': [
              {
                'id': 'image-1',
                'bytesBase64': base64Encode(imageBytes),
                'mimeType': 'image/png',
              },
            ],
            'attachments': [attachment],
            'cover': {
              'name': 'cover.png',
              'bytesBase64': base64Encode(coverBytes),
              'mimeType': 'image/png',
            },
          },
        ),
      },
      settings: const {},
    );
    final binaryStore = FakeCloudBinaryStore();
    final transfer = CloudAssetTransfer(storage: binaryStore);

    final uploaded = await transfer.uploadSnapshot('user-1', snapshot, store);
    final note = uploaded.records['notes:n1']!.data;
    final image = (note['images'] as List).single as Map;
    final uploadedAttachment = (note['attachments'] as List).single as Map;
    final cover = note['cover'] as Map;

    expect(image, isNot(contains('bytesBase64')));
    expect(uploadedAttachment, isNot(contains('bytesBase64')));
    expect(cover, isNot(contains('bytesBase64')));
    expect(binaryStore.values, hasLength(3));
    expect(
      binaryStore.values.keys.every(
        (path) => path.startsWith('users/user-1/assets/'),
      ),
      isTrue,
    );

    final downloaded = await transfer.downloadSnapshot(uploaded);
    final restored = downloaded.records['notes:n1']!.data;
    expect(
      base64Decode(
        ((restored['images'] as List).single as Map)['bytesBase64'] as String,
      ),
      imageBytes,
    );
    expect(
      base64Decode(
        ((restored['attachments'] as List).single as Map)['bytesBase64']
            as String,
      ),
      attachmentBytes,
    );
    expect(
      base64Decode((restored['cover'] as Map)['bytesBase64'] as String),
      coverBytes,
    );
    store.dispose();
  });
}

class FakeCloudBinaryStore implements CloudBinaryStore {
  final values = <String, Uint8List>{};

  @override
  Future<Uint8List?> get(String path, {required int maxBytes}) async {
    final value = values[path];
    if (value == null || value.length > maxBytes) return null;
    return Uint8List.fromList(value);
  }

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String mimeType,
    required String sha256Digest,
  }) async {
    values[path] = Uint8List.fromList(bytes);
  }
}
