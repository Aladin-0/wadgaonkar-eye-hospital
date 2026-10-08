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

  List<dynamic> _patients = [];
  List<dynamic> get patients => _patients;

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

  Future<Map<String, dynamic>> checkIn(String? qrPayload, String? manualCode, {bool preview = false}) async {
    try {
      final result = await adminApiClient.checkIn(qrPayload, manualCode, preview: preview);
      if (result['verified'] == true && !preview) {
        await fetchDashboardData();
      }
      return result;
    } catch (e) {
      return {'error': e.toString(), 'verified': false};
    }
  }

  Future<void> fetchPatients() async {
    _setLoading(true);
    try {
      _patients = await adminApiClient.getPatients();
    } catch (e) {
      _setError('Failed to fetch patients: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveDoctor(String id, Map<String, dynamic> data, {bool isUpdate = false}) async {
    _setLoading(true);
    try {
      await adminApiClient.saveDoctor(id, data, isUpdate: isUpdate);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveService(String id, Map<String, dynamic> data, {bool isUpdate = false}) async {
    _setLoading(true);
    try {
      await adminApiClient.saveService(id, data, isUpdate: isUpdate);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteDoctor(String id) async {
    _setLoading(true);
    try {
      await adminApiClient.deleteDoctor(id);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteService(String id) async {
    _setLoading(true);
    try {
      await adminApiClient.deleteService(id);
    } finally {
      _setLoading(false);
    }
  }

  Future<List<dynamic>> getSlots(String doctorId, String dateStr) async {
    return await adminApiClient.getSlots(doctorId, dateStr);
  }

  Future<void> toggleDoctorUnavailability(String doctorId, String startTime, String endTime, int? existingId) async {
    _setLoading(true);
    try {
      if (existingId != null) {
        await adminApiClient.deleteDoctorUnavailability(existingId);
      } else {
        await adminApiClient.addDoctorUnavailability(doctorId, startTime, endTime, "Doctor Not Available");
      }
    } finally {
      _setLoading(false);
    }
  }
}
