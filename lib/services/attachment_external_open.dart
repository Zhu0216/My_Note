import 'dart:typed_data';

import 'attachment_external_open_stub.dart'
    if (dart.library.io) 'attachment_external_open_io.dart'
    as implementation;

Future<String?> openAttachmentWithSystemApp({
  required String fileName,
  required Uint8List bytes,
}) => implementation.openAttachmentWithSystemApp(
  fileName: fileName,
  bytes: bytes,
);
