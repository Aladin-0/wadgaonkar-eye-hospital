import 'package:flutter_test/flutter_test.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/auth_repository.dart';
import 'package:wadgaonkar_eye_hospital/state/auth_provider.dart';
import 'package:weh_shared/weh_shared.dart';
import 'package:wadgaonkar_eye_hospital/core/errors/app_exception.dart';
import 'dart:async';

class MockAuthRepository implements IAuthRepository {
  bool shouldCancel = false;
  bool shouldFailNetwork = false;
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();
  
  @override
  AuthUser? get currentUser => _currentUser;
  
  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;
  
  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (shouldFailNetwork) throw AuthException('Network error');
    if (shouldCancel) return null;
    
    _currentUser = AuthUser(
      uid: '123',
      email: 'test@patient.com',
      displayName: 'Test Patient',
      photoUrl: null,
      isEmailVerified: true,
    );
    _controller.add(_currentUser);
    return _currentUser;
  }
  
  bool deleteSucceeds = true;

  @override
  Future<AuthUser?> signInWithApple() async {
    if (shouldFailNetwork) throw AuthException('Apple sign-in failed');
    if (shouldCancel) return null;
    _currentUser = AuthUser(
      uid: 'apple-1',
      email: 'private@privaterelay.appleid.com',
      displayName: 'Apple Patient',
      photoUrl: null,
      isEmailVerified: true,
    );
    _controller.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<bool> deleteAccount() async {
    if (!deleteSucceeds) return false;
    _currentUser = null;
    _controller.add(null);
    return true;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
  
  @override
  Future<AuthUser?> restoreSession() async => _currentUser;
}

void main() {
  late MockAuthRepository mockRepo;
  late AuthProvider authProvider;

  setUp(() {
    mockRepo = MockAuthRepository();
    authProvider = AuthProvider(authRepository: mockRepo);
  });

  group('Google Sign-In Auth Boundaries', () {
    test('Google login success through a mocked auth boundary', () async {
      final success = await authProvider.signInWithGoogle();
      expect(success, isTrue);
      expect(authProvider.user, isNotNull);
      expect(authProvider.user!.email, 'test@patient.com');
      expect(authProvider.errorMessage, isNull);
    });

    test('User cancellation', () async {
      mockRepo.shouldCancel = true;
      final success = await authProvider.signInWithGoogle();
      expect(success, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.errorMessage, isNull); // Cancellation shouldn't show error
    });

    test('Network or Firebase authentication failure', () async {
      mockRepo.shouldFailNetwork = true;
      final success = await authProvider.signInWithGoogle();
      expect(success, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.errorMessage, 'Network error');
    });

    test('Logout clears the Firebase session', () async {
      await authProvider.signInWithGoogle();
      expect(authProvider.user, isNotNull);
      
      await authProvider.signOut();
      expect(authProvider.user, isNull);
    });
  });

  group('Sign in with Apple', () {
    test('success signs the user in', () async {
      final success = await authProvider.signInWithApple();
      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user!.uid, 'apple-1');
      expect(authProvider.errorMessage, isNull);
    });

    test('user cancellation shows no error', () async {
      mockRepo.shouldCancel = true;
      final success = await authProvider.signInWithApple();
      expect(success, isFalse);
      expect(authProvider.user, isNull);
      expect(authProvider.errorMessage, isNull);
    });

    test('failure surfaces an error message', () async {
      mockRepo.shouldFailNetwork = true;
      final success = await authProvider.signInWithApple();
      expect(success, isFalse);
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, 'Apple sign-in failed');
    });
  });

  group('Delete account after login', () {
    test('deleting signs the user out', () async {
      await authProvider.signInWithApple();
      expect(authProvider.isAuthenticated, isTrue);

      final ok = await authProvider.deleteAccount();
      expect(ok, isTrue);
      expect(authProvider.user, isNull);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('failed deletion keeps the user signed in', () async {
      await authProvider.signInWithApple();
      mockRepo.deleteSucceeds = false;

      final ok = await authProvider.deleteAccount();
      expect(ok, isFalse);
      expect(authProvider.isAuthenticated, isTrue);
    });
  });
}
