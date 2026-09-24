import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class NoteFileService {
  const NoteFileService._();

  static Future<PlatformFile?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    return result?.files.single;
  }

  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    return result?.files.single;
  }

  static Future<CroppedFile?> cropImage(
    BuildContext context,
    String sourcePath,
  ) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁切圖片',
          toolbarColor: const Color(0xff5967d8),
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.white,
          activeControlsWidgetColor: const Color(0xff5967d8),
          cropFrameColor: const Color(0xff5967d8),
          cropGridColor: const Color(0x665967d8),
          cropFrameStrokeWidth: 3,
          cropGridStrokeWidth: 1,
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          title: '裁切圖片',
          doneButtonTitle: '✓',
          cancelButtonTitle: '✕',
        ),
        WebUiSettings(
          context: context,
          size: const CropperSize(width: 420, height: 420),
          presentStyle: WebPresentStyle.dialog,
        ),
      ],
    );
  }

  static Future<String?> saveBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final location = await FilePicker.platform.saveFile(
      dialogTitle: '儲存附件',
      fileName: fileName,
      bytes: bytes,
    );
    return resolveSavedFileLocation(
      isWeb: kIsWeb,
      fileName: fileName,
      platformLocation: location,
    );
  }

  static Future<Uint8List> buildNotePdf({
    required String title,
    required String body,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title.trim().isEmpty ? '未命名筆記' : title.trim(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(body),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> printNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> shareNotePdf({
    required String title,
    required String body,
  }) async {
    final bytes = await buildNotePdf(title: title, body: body);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${safeExportFileName(title)}.pdf',
    );
  }

  static Future<void> shareText({
    required String title,
    required String body,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: title.trim().isEmpty ? 'My Note' : title.trim(),
        text: body,
      ),
    );
  }
}

String? resolveSavedFileLocation({
  required bool isWeb,
  required String fileName,
  required String? platformLocation,
}) {
  if (isWeb) {
    return fileName;
  }
  return platformLocation;
}

String safeExportFileName(String value) {
  final clean = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return clean.isEmpty ? 'my_note' : clean;
}
