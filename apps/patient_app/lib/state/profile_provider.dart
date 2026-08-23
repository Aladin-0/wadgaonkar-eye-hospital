import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';

import '../data/repositories/profile_repository.dart';

enum ProfileStatus {
  initial,
  loading,
  profileLoaded,
  profileNotFound,
  saving,
  error,
}

/// Manages patient profile creation, retrieval, updates, and persistence
class ProfileProvider extends ChangeNotifier {
  final IProfileRepository profileRepository;

  ProfileStatus _status = ProfileStatus.initial;
  UserProfile? _profile;
  String? _errorMessage;

  ProfileProvider({required this.profileRepository});

  ProfileStatus get status => _status;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get hasCompleteProfile =>
      _status == ProfileStatus.profileLoaded &&
      _profile != null &&
      _profile!.isProfileComplete;
  bool get isLoading =>
      _status == ProfileStatus.loading || _status == ProfileStatus.saving;

  /// Loads patient profile for the given authenticated user
  Future<void> loadProfile(AuthUser authUser) async {
    _status = ProfileStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await profileRepository.getProfile(authUser.uid);

      if (fetched != null && fetched.isProfileComplete) {
        _profile = fetched;
        _status = ProfileStatus.profileLoaded;
      } else {
        // First login or incomplete profile: Prepopulate name and email from Auth
        _profile = UserProfile.empty(
          authUser.uid,
          email: authUser.email,
          displayName: authUser.displayName,
          photoUrl: authUser.photoUrl,
        );
        _status = ProfileStatus.profileNotFound;
      }
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = 'Failed to load profile details.';
    } finally {
      notifyListeners();
    }
  }

  /// Creates and saves a new patient profile after first Google login
  Future<bool> createProfile({
    required String uid,
    required String fullName,
    required String mobileNumber,
    required int age,
    String? email,
    String? photoUrl,
  }) async {
    // Validate inputs
    final nameErr = Validators.validateFullName(fullName);
    if (nameErr != null) {
      _errorMessage = nameErr;
      _status = ProfileStatus.error;
      notifyListeners();
      return false;
    }

    final mobileErr = Validators.validateMobileNumber(mobileNumber);
    if (mobileErr != null) {
      _errorMessage = mobileErr;
      _status = ProfileStatus.error;
      notifyListeners();
      return false;
    }

    final ageErr = Validators.validateAge(age.toString());
    if (ageErr != null) {
      _errorMessage = ageErr;
      _status = ProfileStatus.error;
      notifyListeners();
      return false;
    }

    _status = ProfileStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanMobile = Validators.cleanMobileNumber(mobileNumber);

      final newProfile = UserProfile.create(
        uid: uid,
        fullName: fullName.trim(),
        mobileNumber: cleanMobile,
        age: age,
        email: email?.trim(),
        photoUrl: photoUrl,
      );

      await profileRepository.saveProfile(newProfile);
      _profile = newProfile;
      _status = ProfileStatus.profileLoaded;
      notifyListeners();
      return true;
    } on ProfileException catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = 'Failed to save patient profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Updates existing patient details
  Future<bool> updateProfile({
    required String fullName,
    required String mobileNumber,
    required int age,
    String? email,
  }) async {
    if (_profile == null) return false;

    // Validate inputs
    final nameErr = Validators.validateFullName(fullName);
    if (nameErr != null) {
      _errorMessage = nameErr;
      notifyListeners();
      return false;
    }

    final mobileErr = Validators.validateMobileNumber(mobileNumber);
    if (mobileErr != null) {
      _errorMessage = mobileErr;
      notifyListeners();
      return false;
    }

    final ageErr = Validators.validateAge(age.toString());
    if (ageErr != null) {
      _errorMessage = ageErr;
      notifyListeners();
      return false;
    }

    _status = ProfileStatus.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanMobile = Validators.cleanMobileNumber(mobileNumber);

      final updatedProfile = _profile!.copyWith(
        fullName: fullName.trim(),
        mobileNumber: cleanMobile,
        age: age,
        email: email?.trim(),
        updatedAt: DateTime.now(),
      );

      await profileRepository.updateProfile(updatedProfile);
      _profile = updatedProfile;
      _status = ProfileStatus.profileLoaded;
      notifyListeners();
      return true;
    } on ProfileException catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = ProfileStatus.error;
      _errorMessage = 'Failed to update profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearProfile() {
    _profile = null;
    _status = ProfileStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }
}
