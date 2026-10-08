import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientApiClient {
  late final Dio dio;

  static const String _b = 'https://techverseservices.in/hospital-api/api/v1';

  PatientApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: _b,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<String?> _token() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Options _auth(String? token) => Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

  Future<Map<String, dynamic>?> syncFirebaseUser(Map<String, dynamic> data) async {
    try {
      final response = await dio.post('/auth/firebase-sync/', data: data);
      return response.data;
    } on DioException {
      return null;
    }
  }

  Future<List<dynamic>> getDoctors() async {
    try {
      final response = await dio.get('/doctors/');
      return response.data;
    } on DioException {
      return [];
    }
  }

  Future<List<dynamic>> getServices() async {
    try {
      final response = await dio.get('/services/');
      return response.data;
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>?> calculateFee({
    required String serviceId,
    required String patientUid,
    required String date,
  }) async {
    try {
      final response = await dio.get(
        '/services/$serviceId/calculate_fee/',
        queryParameters: {'patient_uid': patientUid, 'date': date},
      );
      return response.data;
    } on DioException {
      return null;
    }
  }

  Future<List<dynamic>> getPatientAppointments(String patientUid) async {
    try {
      final token = await _token();
      final response = await dio.get(
        '/appointments/',
        queryParameters: {'patient_uid': patientUid},
        options: _auth(token),
      );
      return response.data;
    } on DioException {
      return [];
    }
  }

  Future<List<dynamic>> getSlots(String doctorId, String date, {String? serviceId}) async {
    try {
      final queryParams = <String, dynamic>{'doctor_id': doctorId, 'date': date};
      if (serviceId != null) queryParams['service_id'] = serviceId;
      final response = await dio.get('/appointments/slots/', queryParameters: queryParams);
      return response.data['slots'] as List<dynamic>;
    } on DioException {
      return [];
    }
  }

  Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> data) async {
    try {
      final token = await _token();
      final response = await dio.post(
        '/appointments/',
        data: data,
        options: _auth(token),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Booking failed',
        );
      }
      throw Exception('Network error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> updateAppointmentStatus(
      String appointmentId, Map<String, dynamic> data) async {
    try {
      final token = await _token();
      final response = await dio.patch(
        '/appointments/$appointmentId/',
        data: data,
        options: _auth(token),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Update failed',
        );
      }
      throw Exception('Network error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> rescheduleAppointment(
      String appointmentId, Map<String, dynamic> data) async {
    try {
      final token = await _token();
      final response = await dio.post(
        '/appointments/$appointmentId/reschedule/',
        data: data,
        options: _auth(token),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Reschedule failed',
        );
      }
      throw Exception('Network error. Please try again.');
    }
  }
}
