import 'package:weh_shared/weh_shared.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence service for caching auth session and patient profile
class StorageService {
  static const String _keyAuthUser = 'weh_auth_user';
  static const String _keyUserProfile = 'weh_user_profile';
  static const String _keyIsLoggedIn = 'weh_is_logged_in';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Auth User Persistence ---
  Future<void> saveAuthUser(AuthUser user) async {
    final jsonStr = jsonEncode(user.toMap());
    await _prefs.setString(_keyAuthUser, jsonStr);
    await _prefs.setBool(_keyIsLoggedIn, true);
  }

  AuthUser? getAuthUser() {
    final jsonStr = _prefs.getString(_keyAuthUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuthUser.fromMap(map);
    } catch (e) {
      return null;
    }
  }

  bool isLoggedIn() {
    return _prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // --- User Profile Persistence ---
  Future<void> saveUserProfile(UserProfile profile) async {
    final jsonStr = jsonEncode(profile.toMap());
    await _prefs.setString(_keyUserProfile, jsonStr);
  }

  UserProfile? getUserProfile(String uid) {
    final jsonStr = _prefs.getString(_keyUserProfile);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final profile = UserProfile.fromMap(map);
      if (profile.uid == uid) {
        return profile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Appointments Persistence ---
  static const String _keyAppointments = 'weh_appointments_list';

  Future<void> saveAppointments(List<Appointment> appointments) async {
    final list = appointments.map((a) => a.toMap()).toList();
    await _prefs.setString(_keyAppointments, jsonEncode(list));
  }

  List<Appointment> getAppointments() {
    final jsonStr = _prefs.getString(_keyAppointments);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((item) => Appointment.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAppointment(Appointment appointment) async {
    final list = getAppointments();
    final index = list.indexWhere((a) => a.id == appointment.id);
    if (index >= 0) {
      list[index] = appointment;
    } else {
      list.add(appointment);
    }
    await saveAppointments(list);
  }

  // --- Clear Session ---
  Future<void> clearSession() async {
    await _prefs.remove(_keyAuthUser);
    await _prefs.remove(_keyUserProfile);
    await _prefs.remove(_keyAppointments);
    await _prefs.setBool(_keyIsLoggedIn, false);
  }
}
