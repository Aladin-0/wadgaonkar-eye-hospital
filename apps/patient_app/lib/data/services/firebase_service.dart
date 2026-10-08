import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:wadgaonkar_eye_hospital/firebase_options.dart';

/// Handles push notifications in background/terminated state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  developer.log('Background FCM message received: ${message.messageId}', name: 'FirebaseService');
}

/// Initializes Firebase and manages push notification routing.
class FirebaseService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Set to true when notification is tapped — MainShellScreen reads this on init to refresh
  static bool pendingCancellationRefresh = false;

  /// Broadcast stream: emits `true` whenever a cancellation notification
  /// is received while the app is OPEN (foreground or background resumed).
  static final StreamController<bool> onCancellationNotification =
      StreamController<bool>.broadcast();

  /// Safe initialization.
  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        _isInitialized = false;
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      developer.log('Firebase initialized successfully', name: 'FirebaseService');

      await _setupMessaging();
    } catch (e, stack) {
      _isInitialized = false;
      if (kReleaseMode) {
        throw Exception('CRITICAL: Firebase initialization failed in release mode: $e');
      } else {
        developer.log('Firebase not initialized: $e', name: 'FirebaseService', error: e, stackTrace: stack);
      }
    }
  }

  static Future<void> _setupMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // App FOREGROUND — notification arrives while user is using app
      // Refresh immediately so banner appears without user doing anything
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log('Foreground FCM: ${message.notification?.title}', name: 'FirebaseService');
        onCancellationNotification.add(true);
      });

      // App BACKGROUND — notification arrives, user taps it → app resumes
      // Set flag, MainShellScreen will read it on its next build
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log('Notification tapped (background) — setting pending refresh', name: 'FirebaseService');
        pendingCancellationRefresh = true;
        // Also try stream for fast path if shell is already mounted
        onCancellationNotification.add(true);
      });

      // App KILLED — user taps notification → app launches fresh
      // SplashScreen → MainShellScreen, which reads pendingCancellationRefresh
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        developer.log('App launched from notification tap — setting pending refresh', name: 'FirebaseService');
        pendingCancellationRefresh = true;
      }

      final token = await messaging.getToken();
      developer.log('FCM token: $token', name: 'FirebaseService');
    } catch (e) {
      developer.log('FCM setup error: $e', name: 'FirebaseService');
    }
  }

  /// Get the current FCM device token
  static Future<String?> getFcmToken() async {
    if (!_isInitialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }
}
