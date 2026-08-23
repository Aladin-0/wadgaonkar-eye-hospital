import 'dart:developer' as developer;
import 'package:dio/dio.dart';

class PatientApiClient {
  late final Dio dio;

  // Assuming Django backend runs on localhost:8000 for Linux desktop preview
  // In production, this would be an environment variable.
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  PatientApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  // -- Doctors APIs --
  Future<List<dynamic>> getDoctors() async {
    try {
      final response = await dio.get('/doctors/');
      return response.data;
    } on DioException catch (e) {
      developer.log('Failed to fetch doctors: ${e.message}', name: 'PatientApiClient');
      return [];
    }
  }

  // -- Services APIs --
  Future<List<dynamic>> getServices() async {
    try {
      final response = await dio.get('/services/');
      return response.data;
    } on DioException catch (e) {
      developer.log('Failed to fetch services: ${e.message}', name: 'PatientApiClient');
      return [];
    }
  }

  // -- Appointments APIs --
  Future<List<dynamic>> getPatientAppointments(String patientUid) async {
    try {
      final response = await dio.get('/appointments/', queryParameters: {
        'patient_uid': patientUid,
      });
      return response.data;
    } on DioException catch (e) {
      developer.log('Failed to fetch patient appointments: ${e.message}', name: 'PatientApiClient');
      return [];
    }
  }

  Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> data) async {
    try {
      final response = await dio.post('/appointments/book/', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Booking failed');
      }
      throw Exception('Network error during booking');
    }
  }

  Future<Map<String, dynamic>> updateAppointmentStatus(String appointmentId, Map<String, dynamic> data) async {
    try {
      final response = await dio.patch('/appointments/$appointmentId/', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Update failed');
      }
      throw Exception('Network error during update');
    }
  }
}
