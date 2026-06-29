import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  static bool get isConfigured {
    late final FirebaseOptions options;
    try {
      options = currentPlatform;
    } on UnsupportedError {
      return false;
    }
    return !_isPlaceholder(options.apiKey) &&
        !_isPlaceholder(options.appId) &&
        !_isPlaceholder(options.projectId) &&
        !_isPlaceholder(options.messagingSenderId);
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'Firebase options are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: 'REPLACE_ME.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: 'REPLACE_ME.firebasestorage.app',
    iosBundleId: 'com.allinone.mynote',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    storageBucket: 'REPLACE_ME.firebasestorage.app',
    iosBundleId: 'com.allinone.mynote',
  );

  static bool _isPlaceholder(String value) {
    return value.isEmpty ||
        value == _placeholder ||
        value.contains(_placeholder);
  }
}
