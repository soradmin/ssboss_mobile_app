// Конфигурация Firebase для проекта ssboss-940a1 (FCM / push).
// Realtime Database в этом приложении не используется.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for SSBOSS mobile.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDSqG2daED0p4TkW81gleWjHmaIDtyW83w',
    appId: '1:566190321964:android:657c7b02d2d341bbffbc89',
    messagingSenderId: '566190321964',
    projectId: 'ssboss-940a1',
    storageBucket: 'ssboss-940a1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC1eLz8dthCrw7JL2luz_faSOANPtizekA',
    appId: '1:566190321964:ios:16f74cb3773bfbdcffbc89',
    messagingSenderId: '566190321964',
    projectId: 'ssboss-940a1',
    storageBucket: 'ssboss-940a1.firebasestorage.app',
    iosBundleId: 'com.ssboss.ssbossmp',
  );
}
