import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../data/my_note_data.dart';
import 'cloud_onboarding.dart';

const _maxCloudAssetBytes = 25 * 1024 * 1024;

class CloudAssetTransfer {
  CloudAssetTransfer({CloudBinaryStore? storage})
    : _storage = storage ?? FirebaseCloudBinaryStore();

  final CloudBinaryStore _storage;

  Future<CloudSpaceSnapshot> uploadSnapshot(
    String uid,
    CloudSpaceSnapshot snapshot,
    AppStore store,
  ) async {
    final records = <String, CloudRecord>{};
    for (final record in snapshot.records.values) {
      if (record.collection != 'notes') {
        records[record.key] = record;
        continue;
      }
      final data = cloneJsonMap(record.data);
      data['images'] = await _uploadList(
        uid,
        readMapList(data['images']),
        bytesFor: (item) async => _decode(item['bytesBase64']),
      );
      data['attachments'] = await _uploadList(
        uid,
        readMapList(data['attachments']),
        bytesFor: store.attachmentBytes,
      );
      final cover = readStringMap(data['cover']);
      if (cover.isNotEmpty) {
        data['cover'] = await _uploadItem(
          uid,
          cover,
          bytes: _decode(cover['bytesBase64']),
        );
      }
      final uploaded = CloudRecord(
        collection: record.collection,
        id: record.id,
        data: data,
      );
      records[uploaded.key] = uploaded;
    }
    return CloudSpaceSnapshot(records: records, settings: snapshot.settings);
  }

  Future<CloudSpaceSnapshot> downloadSnapshot(
    CloudSpaceSnapshot snapshot,
  ) async {
    final records = <String, CloudRecord>{};
    for (final record in snapshot.records.values) {
      if (record.collection != 'notes') {
        records[record.key] = record;
        continue;
      }
      final data = cloneJsonMap(record.data);
      data['images'] = await _downloadList(readMapList(data['images']));
      data['attachments'] = await _downloadList(
        readMapList(data['attachments']),
      );
      final cover = readStringMap(data['cover']);
      if (cover.isNotEmpty) data['cover'] = await _downloadItem(cover);
      final downloaded = CloudRecord(
        collection: record.collection,
        id: record.id,
        data: data,
      );
      records[downloaded.key] = downloaded;
    }
    return CloudSpaceSnapshot(records: records, settings: snapshot.settings);
  }

  Future<List<Map<String, dynamic>>> _uploadList(
    String uid,
    List<Map<String, dynamic>> values, {
    required Future<Uint8List?> Function(Map<String, dynamic>) bytesFor,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (final value in values) {
      result.add(await _uploadItem(uid, value, bytes: await bytesFor(value)));
    }
    return result;
  }

  Future<Map<String, dynamic>> _uploadItem(
    String uid,
    Map<String, dynamic> value, {
    required Uint8List? bytes,
  }) async {
    final result = cloneJsonMap(value);
    if (bytes == null || bytes.isEmpty) return result;
    if (bytes.length > _maxCloudAssetBytes) {
      throw StateError('單一同步檔案不可超過 25 MB');
    }
    final digest = sha256.convert(bytes).toString();
    final path = 'users/$uid/assets/$digest';
    final mimeType = readString(value['mimeType']);
    await _storage.put(path, bytes, mimeType: mimeType, sha256Digest: digest);
    result
      ..remove('bytesBase64')
      ..remove('path')
      ..['cloudPath'] = path
      ..['blobId'] = digest
      ..['size'] = bytes.length
      ..['payloadIncluded'] = true;
    return result;
  }

  Future<List<Map<String, dynamic>>> _downloadList(
    List<Map<String, dynamic>> values,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final value in values) {
      result.add(await _downloadItem(value));
    }
    return result;
  }

  Future<Map<String, dynamic>> _downloadItem(Map<String, dynamic> value) async {
    final result = cloneJsonMap(value);
    if (readString(result['bytesBase64']).isNotEmpty) return result;
    final path = readString(result['cloudPath']);
    if (path.isEmpty) return result;
    final bytes = await _storage.get(path, maxBytes: _maxCloudAssetBytes);
    if (bytes == null) throw StateError('雲端檔案內容不存在');
    final expected = readString(result['blobId']);
    final actual = sha256.convert(bytes).toString();
    if (expected.isNotEmpty && expected != actual) {
      throw StateError('雲端檔案完整性驗證失敗');
    }
    result
      ..['bytesBase64'] = base64Encode(bytes)
      ..['blobId'] = actual
      ..['size'] = bytes.length
      ..['payloadIncluded'] = true;
    return result;
  }
}

abstract interface class CloudBinaryStore {
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String mimeType,
    required String sha256Digest,
  });

  Future<Uint8List?> get(String path, {required int maxBytes});
}

class FirebaseCloudBinaryStore implements CloudBinaryStore {
  FirebaseCloudBinaryStore({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String mimeType,
    required String sha256Digest,
  }) async {
    await _storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: mimeType.isEmpty ? null : mimeType,
            customMetadata: {'sha256': sha256Digest},
          ),
        );
  }

  @override
  Future<Uint8List?> get(String path, {required int maxBytes}) =>
      _storage.ref(path).getData(maxBytes);
}

Uint8List? _decode(Object? value) {
  final encoded = readString(value);
  if (encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}
