import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Handles push notifications for late-arrival reminders and doctor unavailability alerts.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  developer.log('Background FCM message received: ${message.messageId}', name: 'FirebaseService');
}

/// Initializes and checks Firebase connection status safely
class FirebaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Safe initialization that catches missing configuration files gracefully
  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        _isInitialized = false;
        developer.log('Firebase on Web pending configuration', name: 'FirebaseService');
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      developer.log('Firebase initialized successfully', name: 'FirebaseService');

      // Setup FCM handlers after Firebase is confirmed initialized
      await _setupMessaging();
    } catch (e, stack) {
      _isInitialized = false;
      if (kReleaseMode) {
        // In release mode, Firebase config MUST exist and be valid
        throw Exception('CRITICAL: Firebase initialization failed in release mode: $e');
      } else {
        developer.log(
          'Firebase not initialized: $e',
          name: 'FirebaseService',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  static Future<void> _setupMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS, macOS)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          'Foreground FCM: ${message.notification?.title} - ${message.notification?.body}',
          name: 'FirebaseService',
        );
        // TODO: Show in-app banner or dialog
      });

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log(
          'App opened from FCM: ${message.data}',
          name: 'FirebaseService',
        );
        // TODO: Navigate to the relevant appointment screen
      });

      final token = await messaging.getToken();
      developer.log('FCM token: $token', name: 'FirebaseService');
    } catch (e) {
      developer.log('FCM setup error: $e', name: 'FirebaseService');
    }
  }

  /// Get the current FCM device token for registering with backend
  static Future<String?> getFcmToken() async {
    if (!_isInitialized) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }
}
