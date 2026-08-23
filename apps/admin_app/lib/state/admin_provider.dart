import 'package:flutter/foundation.dart';
import '../data/services/admin_api_client.dart';

class AdminProvider extends ChangeNotifier {
  final AdminApiClient adminApiClient;

  AdminProvider({required this.adminApiClient});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<dynamic> _todayAppointments = [];
  List<dynamic> get todayAppointments => _todayAppointments;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final success = await adminApiClient.login(username, password);
      if (!success) {
        _setError('Invalid credentials or network error.');
      }
      return success;
    } catch (e) {
      _setError('Login failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await adminApiClient.logout();
    _todayAppointments.clear();
    notifyListeners();
  }

  Future<bool> checkIsLoggedIn() async {
    return await adminApiClient.isLoggedIn();
  }

  Future<void> fetchDashboardData() async {
    _setLoading(true);
    try {
      _todayAppointments = await adminApiClient.getAppointments();
    } catch (e) {
      _setError('Failed to fetch dashboard data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> checkIn(String? qrPayload, String? manualCode) async {
    try {
      final result = await adminApiClient.checkIn(qrPayload, manualCode);
      if (result['verified'] == true) {
        await fetchDashboardData();
      }
      return result;
    } catch (e) {
      return {'error': e.toString(), 'verified': false};
    }
  }
}
