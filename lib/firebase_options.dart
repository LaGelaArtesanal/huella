import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ✅ CONFIGURACIÓN WEB (con tus credenciales reales)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDUZMZbvbI_hefFEm64ymO4_ZyBnSoC_QM',
    authDomain: 'huella2.firebaseapp.com',
    projectId: 'huella2',
    storageBucket: 'huella2.firebasestorage.app',
    messagingSenderId: '886773009345',
    appId: '1:886773009345:web:4677c090a9a59cef403d40',
    measurementId: 'G-M3W7968L2G',
  );

  // ✅ CONFIGURACIÓN ANDROID (debes obtenerla de tu google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUZMZbvbI_hefFEm64ymO4_ZyBnSoC_QM',
    authDomain: 'huella2.firebaseapp.com',
    projectId: 'huella2',
    storageBucket: 'huella2.firebasestorage.app',
    messagingSenderId: '886773009345',
    appId: '1:886773009345:web:4677c090a9a59cef403d40',
  );

  // ✅ CONFIGURACIÓN iOS (placeholder - completar cuando agregues iOS)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUZMZbvbI_hefFEm64ymO4_ZyBnSoC_QM',
    authDomain: 'huella2.firebaseapp.com',
    projectId: 'huella2',
    storageBucket: 'huella2.firebasestorage.app',
    messagingSenderId: '886773009345',
    appId: '1:886773009345:web:4677c090a9a59cef403d40',
    iosBundleId: 'com.example.huella',
  );

  // ✅ CONFIGURACIÓN WINDOWS (placeholder)
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDUZMZbvbI_hefFEm64ymO4_ZyBnSoC_QM',
    authDomain: 'huella2.firebaseapp.com',
    projectId: 'huella2',
    storageBucket: 'huella2.firebasestorage.app',
    messagingSenderId: '886773009345',
    appId: '1:886773009345:web:4677c090a9a59cef403d40',
  );
}