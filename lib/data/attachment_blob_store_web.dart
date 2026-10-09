import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'attachment_blob_store.dart';

AttachmentBlobStore createAttachmentBlobStore() =>
    IndexedDbAttachmentBlobStore();

class IndexedDbAttachmentBlobStore implements AttachmentBlobStore {
  static const _databaseName = 'my_note_attachment_blobs';
  static const _storeName = 'blobs';
  Future<web.IDBDatabase>? _databaseFuture;

  Future<web.IDBDatabase> _database() => _databaseFuture ??= _open();

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    }).toJS;
    request.onsuccess = ((web.Event event) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event event) {
      completer.completeError(
        StateError(request.error?.message ?? 'IndexedDB open failed'),
      );
    }).toJS;
    return completer.future;
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      completer.completeError(
        StateError(request.error?.message ?? 'IndexedDB request failed'),
      );
    }).toJS;
    return completer.future;
  }

  Future<web.IDBObjectStore> _objectStore(String mode) async {
    final database = await _database();
    return database.transaction(_storeName.toJS, mode).objectStore(_storeName);
  }

  @override
  Future<String> put(Uint8List bytes) async {
    final id = attachmentBlobId(bytes);
    if (await contains(id)) return id;
    final store = await _objectStore('readwrite');
    await _request(store.put(base64Encode(bytes).toJS, id.toJS));
    final verified = await read(id);
    if (verified == null || attachmentBlobId(verified) != id) {
      await delete(id);
      throw StateError('Attachment verification failed');
    }
    return id;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final store = await _objectStore('readonly');
    final result = (await _request(store.get(id.toJS))).dartify();
    if (result is! String) return null;
    return base64Decode(result);
  }

  @override
  Future<bool> contains(String id) async {
    final store = await _objectStore('readonly');
    final result = (await _request(store.count(id.toJS))).dartify();
    return result is num && result > 0;
  }

  @override
  Future<Set<String>> listIds() async {
    final store = await _objectStore('readonly');
    final result = (await _request(store.getAllKeys())).dartify();
    if (result is! List) return <String>{};
    return result.whereType<String>().toSet();
  }

  @override
  Future<void> delete(String id) async {
    final store = await _objectStore('readwrite');
    await _request(store.delete(id.toJS));
  }
}
