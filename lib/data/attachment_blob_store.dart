import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'attachment_blob_store_stub.dart'
    if (dart.library.io) 'attachment_blob_store_io.dart'
    if (dart.library.js_interop) 'attachment_blob_store_web.dart'
    as platform;

abstract interface class AttachmentBlobStore {
  Future<String> put(Uint8List bytes);

  Future<Uint8List?> read(String id);

  Future<bool> contains(String id);

  Future<Set<String>> listIds();

  Future<void> delete(String id);
}

const int maxAttachmentBytes = 25 * 1024 * 1024;
const int attachmentWarningBoundaryBytes = 100 * 1024 * 1024;
const int maxNoteAttachmentBytes = 125 * 1024 * 1024;

class AttachmentLimitException implements Exception {
  const AttachmentLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

void validateAttachmentCapacity({
  required int currentBytes,
  required int newAttachmentBytes,
}) {
  if (newAttachmentBytes > maxAttachmentBytes) {
    throw const AttachmentLimitException('單一附件不可超過 25 MB');
  }
  if (currentBytes > attachmentWarningBoundaryBytes) {
    throw const AttachmentLimitException('此筆記附件已超過 100 MB，無法再新增附件');
  }
  if (currentBytes + newAttachmentBytes > maxNoteAttachmentBytes) {
    throw const AttachmentLimitException('此筆記附件不可超過 125 MB');
  }
}

String attachmentBlobId(Uint8List bytes) => sha256.convert(bytes).toString();

AttachmentBlobStore createPlatformAttachmentBlobStore() =>
    platform.createAttachmentBlobStore();

class MemoryAttachmentBlobStore implements AttachmentBlobStore {
  final Map<String, Uint8List> _values = {};

  @override
  Future<String> put(Uint8List bytes) async {
    final id = attachmentBlobId(bytes);
    _values.putIfAbsent(id, () => Uint8List.fromList(bytes));
    return id;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final bytes = _values[id];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<bool> contains(String id) async => _values.containsKey(id);

  @override
  Future<Set<String>> listIds() async => _values.keys.toSet();

  @override
  Future<void> delete(String id) async => _values.remove(id);
}
