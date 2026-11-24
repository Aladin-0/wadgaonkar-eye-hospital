import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:wadgaonkar_eye_hospital/data/repositories/auth_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/profile_repository.dart';
import 'package:wadgaonkar_eye_hospital/state/auth_provider.dart';
import 'package:wadgaonkar_eye_hospital/state/profile_provider.dart';
import 'package:wadgaonkar_eye_hospital/ui/screens/auth/login_screen.dart';

class MockAuthRepository implements IAuthRepository {
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_user);

  @override
  Future<AuthUser?> restoreSession() async => _user;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    _user = const AuthUser(
      uid: 'test_uid',
      email: 'patient@example.com',
      displayName: 'Aarav Patil',
    );
    return _user;
  }

  @override
  Future<AuthUser?> signInWithApple() async => signInWithGoogle();

  @override
  Future<bool> deleteAccount() async {
    _user = null;
    return true;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class MockProfileRepository implements IProfileRepository {
  UserProfile? _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<UserProfile?> getProfile(String uid) async => _profile;

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
  }
}

void main() {
  testWidgets('LoginScreen displays hospital branding and Google button',
      (WidgetTester tester) async {
    final mockAuth = MockAuthRepository();
    final mockProfile = MockProfileRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<IAuthRepository>.value(value: mockAuth),
          Provider<IProfileRepository>.value(value: mockProfile),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(authRepository: mockAuth),
          ),
          ChangeNotifierProvider<ProfileProvider>(
            create: (_) => ProfileProvider(profileRepository: mockProfile),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // Verify hospital name and Google Sign In button are displayed
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
  });
}
