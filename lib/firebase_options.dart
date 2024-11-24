import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

// Firebase 콘솔에서 가져온 설정값들
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-vFp2sEjgeSYIqYs1x8cq14os8HoqKjYk',
    appId: '1:7456379458471:android:e09beacc3a12221b3977262',
    messagingSenderId: '7456379587471',
    projectId: 'flutterkakaomlkits',
    databaseURL: 'https://flutterkakaomlkits-default-rtdb.firebaseio.com',
    storageBucket: 'flutterkakaomlkits.firebasestorage.app',
  );

  // 이 값은 파이어베이스 json파일에서 있음

  // static const FirebaseOptions android = FirebaseOptions(
  //     apiKey: 'your-api-key', // Firebase 콘솔에서 확인
  //     appId: 'your-app-id', // Firebase 콘솔에서 확인
  //     messagingSenderId: 'sender-id', // Firebase 콘솔에서 확인
  //     projectId: 'mlkitfacedetection-41f1d',
  //     databaseURL: 'your-database-url', // Realtime Database URL
  //     storageBucket: 'your-storage-bucket' // Storage 버킷
  //     );
}
