import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class AdminApiClient {
  final SecureStorageService secureStorageService;
  late final Dio dio;

  // Assuming Django backend runs on localhost:8000 for Linux desktop preview
  // In production, this would be an environment variable.
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  AdminApiClient(this.secureStorageService) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorageService.getAdminToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
          // Token expired or invalid
          await secureStorageService.clearAdminToken();
          developer.log('Admin token expired or invalid.', name: 'AdminApiClient');
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await dio.post('/auth/admin/login/', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 200 && response.data != null) {
        final token = response.data['access'];
        if (token != null) {
          await secureStorageService.saveAdminToken(token);
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      developer.log('Admin login error: ${e.response?.data}', name: 'AdminApiClient');
      return false;
    }
  }

  Future<void> logout() async {
    await secureStorageService.clearAdminToken();
  }

  Future<bool> isLoggedIn() async {
    return await secureStorageService.getAdminToken() != null;
  }

  // -- Check-in APIs --
  Future<Map<String, dynamic>> checkIn(String? qrPayload, String? manualCode) async {
    try {
      final data = <String, dynamic>{};
      if (qrPayload != null) data['qr_payload'] = qrPayload;
      if (manualCode != null) data['appointment_code'] = manualCode;
      final response = await dio.post('/appointments/check_in/', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['error'] ?? 'Check-in failed');
      }
      throw Exception('Network error during check-in');
    }
  }

  // -- Appointments APIs --
  Future<List<dynamic>> getAppointments() async {
    try {
      final response = await dio.get('/appointments/');
      return response.data;
    } on DioException catch (e) {
      developer.log('Failed to fetch appointments: ${e.message}', name: 'AdminApiClient');
      return [];
    }
  }

  // -- Doctors APIs --
  Future<List<dynamic>> getDoctors() async {
    try {
      final response = await dio.get('/doctors/');
      return response.data;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> saveDoctor(String id, Map<String, dynamic> data, {bool isUpdate = false}) async {
    try {
      if (isUpdate) {
        await dio.patch('/doctors/$id/', data: data);
      } else {
        data['id'] = id;
        await dio.post('/doctors/', data: data);
      }
    } on DioException catch (e) {
      developer.log('Failed to save doctor: ${e.message}', name: 'AdminApiClient');
      throw Exception(e.response?.data ?? 'Error saving doctor');
    }
  }

  // -- Services APIs --
  Future<List<dynamic>> getServices() async {
    try {
      final response = await dio.get('/services/');
      return response.data;
    } on DioException catch (_) {
      return [];
    }
  }

  Future<void> saveService(String id, Map<String, dynamic> data, {bool isUpdate = false}) async {
    try {
      if (isUpdate) {
        await dio.patch('/services/$id/', data: data);
      } else {
        data['id'] = id;
        await dio.post('/services/', data: data);
      }
    } on DioException catch (e) {
      developer.log('Failed to save service: ${e.message}', name: 'AdminApiClient');
      throw Exception(e.response?.data ?? 'Error saving service');
    }
  }

  // -- Patients APIs --
  Future<List<dynamic>> getPatients() async {
    try {
      final response = await dio.get('/auth/profiles/');
      if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      }
      return response.data;
    } on DioException catch (e) {
      developer.log('Failed to fetch patients: ${e.message}', name: 'AdminApiClient');
      return [];
    }
  }
}
