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
    apiKey: 'AIzaSyC34YsRlpcleCM8h_Cm0L6gjjjuKNOeMMc',
    appId: '1:77505458462:web:1562d79426d0965836d90f',
    messagingSenderId: '77505458462',
    projectId: 'first-firebase-project-1111',
    authDomain: 'first-firebase-project-1111.firebaseapp.com',
    storageBucket: 'first-firebase-project-1111.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBbog94UonUrXe4AMGRD-7s0-1VrdV-8ak',
    appId: '1:77505458462:android:b24344f61d653fe136d90f',
    messagingSenderId: '77505458462',
    projectId: 'first-firebase-project-1111',
    storageBucket: 'first-firebase-project-1111.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCJV_KWgjkIOb9XDOtXvv4Wr5jF40TNeTs',
    appId: '1:77505458462:ios:69f0274a9798949e36d90f',
    messagingSenderId: '77505458462',
    projectId: 'first-firebase-project-1111',
    storageBucket: 'first-firebase-project-1111.firebasestorage.app',
    iosBundleId: 'com.allinone.mynote',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCJV_KWgjkIOb9XDOtXvv4Wr5jF40TNeTs',
    appId: '1:77505458462:ios:69f0274a9798949e36d90f',
    messagingSenderId: '77505458462',
    projectId: 'first-firebase-project-1111',
    storageBucket: 'first-firebase-project-1111.firebasestorage.app',
    iosBundleId: 'com.allinone.mynote',
  );

  static bool _isPlaceholder(String value) {
    return value.isEmpty ||
        value == _placeholder ||
        value.contains(_placeholder);
  }
}
