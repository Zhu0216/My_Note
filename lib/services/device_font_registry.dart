import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const deviceFontChannel = MethodChannel('my_note/device_font');
const noteRuntimeDeviceFontFamily = 'MyNoteDeviceSystemFont';
const noteRuntimeDeviceFontPrefix = 'MyNoteInstalledDeviceFont';
const noteDeviceFontValuePrefix = 'DeviceFont:';

String? loadedDeviceSystemFontFamily;
String loadedDeviceSystemFontDisplayName = '';
final Map<String, DeviceFontOption> loadedDeviceFontOptions = {};

class DeviceFontOption {
  const DeviceFontOption({
    required this.packageName,
    required this.displayName,
    required this.fontFamily,
  });

  final String packageName;
  final String displayName;
  final String fontFamily;
}

Future<void> loadDeviceSystemFontIfAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    final rawCatalog = await deviceFontChannel
        .invokeMethod<Map<Object?, Object?>>('loadFontCatalog');
    if (rawCatalog == null) {
      return;
    }
    final currentPackage = rawCatalog['currentPackage']?.toString() ?? '';
    final rawFonts = rawCatalog['fonts'];
    if (rawFonts is! List) {
      return;
    }
    var index = 0;
    for (final rawFont in rawFonts) {
      if (rawFont is! Map) {
        continue;
      }
      final packageName = rawFont['packageName']?.toString() ?? '';
      final displayName = rawFont['displayName']?.toString() ?? '';
      final bytes = rawFont['bytes'];
      if (packageName.isEmpty ||
          displayName.isEmpty ||
          bytes is! Uint8List ||
          bytes.isEmpty) {
        continue;
      }
      final fontFamily = packageName == currentPackage
          ? noteRuntimeDeviceFontFamily
          : '$noteRuntimeDeviceFontPrefix$index';
      final loader = FontLoader(fontFamily)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      loadedDeviceFontOptions[packageName] = DeviceFontOption(
        packageName: packageName,
        displayName: displayName,
        fontFamily: fontFamily,
      );
      if (packageName == currentPackage) {
        loadedDeviceSystemFontFamily = fontFamily;
        loadedDeviceSystemFontDisplayName = displayName;
      }
      index++;
    }
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}
