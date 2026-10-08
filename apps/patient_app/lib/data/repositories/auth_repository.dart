import 'package:weh_shared/weh_shared.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/app_exception.dart';

import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/patient_api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

abstract class IAuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
  Future<AuthUser?> restoreSession();
}

class AuthRepository implements IAuthRepository {
  final StorageService storageService;
  final GoogleSignIn _googleSignIn;
  fb_auth.FirebaseAuth? _firebaseAuth;

  final _authController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  AuthRepository({
    required this.storageService,
    GoogleSignIn? googleSignIn,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId: '1003169726058-d5ich4uf8omjg0stm6ne74qj7b9atpkb.apps.googleusercontent.com',
            ) {
    if (FirebaseService.isInitialized) {
      try {
        _firebaseAuth = fb_auth.FirebaseAuth.instance;
        _firebaseAuth?.authStateChanges().listen(_onFirebaseAuthChanged);
      } catch (e) {
        developer.log('FirebaseAuth instance error: $e', name: 'AuthRepository');
      }
    }
  }

  void _onFirebaseAuthChanged(fb_auth.User? firebaseUser) {
    if (firebaseUser != null) {
      final user = AuthUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: firebaseUser.emailVerified,
      );
      _currentUser = user;
      storageService.saveAuthUser(user);
      _authController.add(user);
    } else {
      if (!FirebaseService.isInitialized && _currentUser != null) {
        // Keep local session if running in fallback mode
        return;
      }
      _currentUser = null;
      _authController.add(null);
    }
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _authController.stream;

  @override
  Future<AuthUser?> restoreSession() async {
    final cached = storageService.getAuthUser();
    if (cached != null) {
      _currentUser = cached;
      _authController.add(cached);
      
      // Sync with Django Backend to update FCM token on app start
      try {
        String? fcmToken;
        if (FirebaseService.isInitialized) {
          fcmToken = await FirebaseMessaging.instance.getToken();
        }
        
        final client = PatientApiClient();
        await client.syncFirebaseUser({
          'uid': cached.uid,
          'email': cached.email,
          'display_name': cached.displayName,
          'fcm_token': fcmToken,
        });
      } catch (e) {
        developer.log('Failed to sync with backend on restore: $e', name: 'AuthRepository');
      }
      
      return cached;
    }
    return null;
  }

  // ignore: constant_identifier_names
  static const bool ENABLE_AUTH_MOCK = false;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      // 1. Force real Google Sign-In if mock is disabled, OR if Firebase is active
      if (!ENABLE_AUTH_MOCK || (FirebaseService.isInitialized && _firebaseAuth != null)) {
        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

          if (googleUser == null) {
            // User explicitly cancelled the Google Sign-in flow
            developer.log('Google sign-in cancelled by user', name: 'AuthRepository');
            return null;
          }

          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          final fb_auth.AuthCredential credential =
              fb_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // If _firebaseAuth is null (e.g. Firebase failed to init), we initialize it here or it will throw.
          final authInstance = _firebaseAuth ?? fb_auth.FirebaseAuth.instance;

          final fb_auth.UserCredential userCredential =
              await authInstance.signInWithCredential(credential);

          final fb_auth.User? fbUser = userCredential.user;
          if (fbUser == null) {
            throw AuthException('Failed to retrieve user identity from Firebase.');
          }

          final authUser = AuthUser(
            uid: fbUser.uid,
            email: fbUser.email ?? googleUser.email,
            displayName: fbUser.displayName ?? googleUser.displayName,
            photoUrl: fbUser.photoURL ?? googleUser.photoUrl,
            isEmailVerified: fbUser.emailVerified,
          );
          
          // Sync with Django Backend
          try {
            String? fcmToken;
            if (FirebaseService.isInitialized) {
              fcmToken = await FirebaseMessaging.instance.getToken();
            }
            
            final client = PatientApiClient();
            await client.syncFirebaseUser({
              'uid': authUser.uid,
              'email': authUser.email,
              'display_name': authUser.displayName,
              'fcm_token': fcmToken,
            });
          } catch (e) {
            developer.log('Failed to sync with backend: $e', name: 'AuthRepository');
          }

          _currentUser = authUser;
          await storageService.saveAuthUser(authUser);
          _authController.add(authUser);
          return authUser;
        } on PlatformException catch (e) {
          developer.log(
            'DEBUG LOGIN ERROR:\n'
            'Type: PlatformException\n'
            'Code: ${e.code}\n'
            'Message: ${e.message}\n'
            'Mode: ${kDebugMode ? "Debug" : (kProfileMode ? "Profile" : "Release")}\n'
            'Package: com.wadgaonkareyehospital.wadgaonkar_eye_hospital',
            name: 'AuthRepository',
          );
          if (kDebugMode) {
            rethrow;
          }
          throw AuthException('Platform error during sign-in: ${e.code}');
        }
      } else {
        // 2. Safe Fallback / Dev Mode Flow:
        if (!kDebugMode) {
          throw AuthException(
            'Authentication service is not configured for production. '
            'Please verify Google Services configuration or contact hospital support.',
          );
        }

        developer.log(
          '⚠️ [DEBUG ONLY] Using development Google Sign-In pipeline fallback',
          name: 'AuthRepository',
        );

        // Simulate network latency
        await Future.delayed(const Duration(milliseconds: 900));

        final authUser = AuthUser(
          uid: 'WEH-GOOGLE-USER-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          email: 'patient.care@gmail.com',
          displayName: 'Ramesh Patil',
          photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
          isEmailVerified: true,
        );

        _currentUser = authUser;
        await storageService.saveAuthUser(authUser);
        _authController.add(authUser);
        return authUser;
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      developer.log(
        'DEBUG LOGIN ERROR:\n'
        'Type: FirebaseAuthException\n'
        'Code: ${e.code}\n'
        'Message: ${e.message}\n'
        'Mode: ${kDebugMode ? "Debug" : (kProfileMode ? "Profile" : "Release")}\n'
        'Package: com.wadgaonkareyehospital.wadgaonkar_eye_hospital',
        name: 'AuthRepository', 
      );
      if (kDebugMode) rethrow;
      throw AuthException(
        e.message ?? 'An error occurred during authentication.',
        code: e.code,
      );
    } catch (e) {
      developer.log('Unexpected auth error: $e',
          name: 'AuthRepository', error: e);
      if (kDebugMode) rethrow;
      if (e is AuthException) rethrow;
      throw AuthException('Failed to complete sign-in. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (FirebaseService.isInitialized && _firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
          await _googleSignIn.signOut();
        }
      } catch (_) {}

      await storageService.clearSession();
      _currentUser = null;
      _authController.add(null);
    } catch (e) {
      developer.log('Sign-out error: $e', name: 'AuthRepository');
      // Ensure local state is cleared anyway
      await storageService.clearSession();
      _currentUser = null;
      _authController.add(null);
    }
  }
}
