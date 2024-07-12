import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    authDomain: 'flutterslitherlink.firebaseapp.com',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
    messagingSenderId: '421943540928',
    appId: '1:421943540928:web:94cadd0cea8ce681fac125',
    measurementId: 'G-KKRP1N8RGC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    appId: '1:421943540928:android:70460ca5c81871aefac125',
    messagingSenderId: '421943540928',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    appId: '1:421943540928:ios:797bd3c7e88a33fffac125',
    messagingSenderId: '421943540928',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
    iosClientId: '421943540928-9elt3sj46587inae4n94m04g2v7m7djr.apps.googleusercontent.com',
    iosBundleId: 'slitherlink.com.puzzle.glorygem.slitherlinkProject',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    appId: '1:421943540928:ios:797bd3c7e88a33fffac125',
    messagingSenderId: '421943540928',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
    iosClientId: '421943540928-9elt3sj46587inae4n94m04g2v7m7djr.apps.googleusercontent.com',
    iosBundleId: 'slitherlink.com.puzzle.glorygem.slitherlinkProject',
  );


  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    appId: '1:421943540928:web:9cc9a8d9a7a8f6cbfac125',
    messagingSenderId: '421943540928',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAdhQ_YJN5dSXogdLpS_6Flfhiar0yKFpM',
    appId: '1:421943540928:web:9cc9a8d9a7a8f6cbfac125',
    messagingSenderId: '421943540928',
    projectId: 'flutterslitherlink',
    storageBucket: 'flutterslitherlink.appspot.com',
  );
}
