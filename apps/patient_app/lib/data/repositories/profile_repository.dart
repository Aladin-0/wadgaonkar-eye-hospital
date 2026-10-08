import 'package:weh_shared/weh_shared.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';

import '../services/firebase_service.dart';
import '../services/storage_service.dart';

abstract class IProfileRepository {
  Future<UserProfile?> getProfile(String uid);
  Future<void> saveProfile(UserProfile profile);
  Future<void> updateProfile(UserProfile profile);
}

class ProfileRepository implements IProfileRepository {
  final StorageService storageService;
  FirebaseFirestore? _firestore;

  ProfileRepository({
    required this.storageService,
  }) {
    if (FirebaseService.isInitialized) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        developer.log('FirebaseFirestore instance error: $e',
            name: 'ProfileRepository');
      }
    }
  }

  static const String _collectionPatients = 'patients';

  @override
  Future<UserProfile?> getProfile(String uid) async {
    try {
      // 1. Try fetching from Firestore if active
      if (FirebaseService.isInitialized && _firestore != null) {
        final doc =
            await _firestore!.collection(_collectionPatients).doc(uid).get();

        if (doc.exists && doc.data() != null) {
          final profile = UserProfile.fromMap(doc.data()!);
          // Cache locally
          await storageService.saveUserProfile(profile);
          return profile;
        }
      }

      // 2. Fallback to local storage cache
      final localProfile = storageService.getUserProfile(uid);
      return localProfile;
    } catch (e) {
      developer.log('Error fetching user profile: $e',
          name: 'ProfileRepository', error: e);
      // Fallback to local cache on network error
      return storageService.getUserProfile(uid);
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    try {
      // 1. Save to local storage first for instant feedback and offline reliability
      await storageService.saveUserProfile(profile);

      // 2. Sync to Cloud Firestore if active
      if (FirebaseService.isInitialized && _firestore != null) {
        await _firestore!
            .collection(_collectionPatients)
            .doc(profile.uid)
            .set(profile.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      developer.log('Error saving profile to cloud: $e',
          name: 'ProfileRepository', error: e);
      // We swallow the error because local save was successful. Offline-first!
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await saveProfile(updated);
  }
}
