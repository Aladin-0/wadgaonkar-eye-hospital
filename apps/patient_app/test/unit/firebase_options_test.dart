import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wadgaonkar_eye_hospital/firebase_options.dart';

/// Regression test for the App Store rejection (guideline 2.1, "blank page
/// upon launch"): the iOS Firebase options were missing, so on iPhone/iPad
/// `DefaultFirebaseOptions.currentPlatform` threw, Firebase never started,
/// and the release build never reached runApp().
void main() {
  test('Firebase options are configured for iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.appId, contains(':ios:'));
      expect(options.projectId, 'wadgaonkar-eye-hospital');
      expect(
        options.iosBundleId,
        'com.wadgaonkareyehospital.wadgaonkarEyeHospital',
      );
      expect(options.iosClientId, isNotEmpty);
      expect(options.apiKey, isNotEmpty);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('Firebase options are configured for Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.appId, contains(':android:'));
      expect(options.projectId, 'wadgaonkar-eye-hospital');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
