import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';

import 'attachment_blob_store.dart';

AttachmentBlobStore createAttachmentBlobStore() => FileAttachmentBlobStore();

class FileAttachmentBlobStore implements AttachmentBlobStore {
  final MemoryAttachmentBlobStore _testFallback = MemoryAttachmentBlobStore();
  Future<Directory?>? _directoryFuture;

  Future<Directory?> _directory() => _directoryFuture ??= _openDirectory();

  Future<Directory?> _openDirectory() async {
    late final Directory root;
    try {
      root = await getApplicationSupportDirectory();
    } on MissingPluginException {
      return null;
    }
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}attachments',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File?> _file(String id) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid attachment blob ID');
    }
    final directory = await _directory();
    if (directory == null) return null;
    return File('${directory.path}${Platform.pathSeparator}$id.blob');
  }

  @override
  Future<String> put(Uint8List bytes) async {
    final id = attachmentBlobId(bytes);
    final destination = await _file(id);
    if (destination == null) return _testFallback.put(bytes);
    if (await destination.exists()) {
      return id;
    }
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    final verified = await temporary.readAsBytes();
    if (attachmentBlobId(verified) != id) {
      await temporary.delete();
      throw const FileSystemException('Attachment verification failed');
    }
    try {
      await temporary.rename(destination.path);
    } on FileSystemException {
      if (!await destination.exists()) rethrow;
      await temporary.delete();
    }
    return id;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    if (file == null) return _testFallback.read(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<bool> contains(String id) async {
    final file = await _file(id);
    return file == null ? _testFallback.contains(id) : file.exists();
  }

  @override
  Future<Set<String>> listIds() async {
    final directory = await _directory();
    if (directory == null) return _testFallback.listIds();
    final result = <String>{};
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.blob')) continue;
      final name = entity.uri.pathSegments.last;
      final id = name.substring(0, name.length - '.blob'.length);
      if (RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) result.add(id);
    }
    return result;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (file == null) return _testFallback.delete(id);
    if (await file.exists()) await file.delete();
  }
}
