import 'package:weh_shared/weh_shared.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';

import '../data/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

/// Manages authentication lifecycle and user session
class AuthProvider extends ChangeNotifier {
  final IAuthRepository authRepository;

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _user;
  String? _errorMessage;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthProvider({required this.authRepository}) {
    _init();
  }

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isAuthenticating => _status == AuthStatus.authenticating;

  void _init() {
    _authSubscription = authRepository.authStateChanges.listen((user) {
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
      } else if (_status != AuthStatus.authenticating) {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  /// Restores existing session from local storage on app start
  Future<void> restoreSession() async {
    try {
      _status = AuthStatus.authenticating;
      notifyListeners();

      final restored = await authRepository.restoreSession();
      if (restored != null) {
        _user = restored;
        _status = AuthStatus.authenticated;
      } else {
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Initiates Google Sign-In flow
  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await authRepository.signInWithGoogle();

      if (user == null) {
        // User cancelled the login popup
        _status = _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _user = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Signs out the user and clears state
  Future<void> signOut() async {
    _status = AuthStatus.authenticating;
    notifyListeners();

    try {
      await authRepository.signOut();
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
