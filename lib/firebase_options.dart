// File generated for MyUPI using google-services.json from Firebase Console.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web/desktop.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDC7FiLONfONLh3G7Zsw7kqPhhXeBdXXkA',
    appId: '1:336803590129:android:db0a5bc148cfa69758de50',
    messagingSenderId: '336803590129',
    projectId: 'myupi1',
    storageBucket: 'myupi1.firebasestorage.app',
  );
}
