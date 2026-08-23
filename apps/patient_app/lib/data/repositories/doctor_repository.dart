import 'package:weh_shared/weh_shared.dart';
import 'dart:developer' as developer;
import '../services/patient_api_client.dart';

abstract class IDoctorRepository {
  Future<List<Doctor>> getDoctors();
  Future<Doctor?> getDoctorById(String id);
  Future<List<Doctor>> getDoctorsByService(String serviceId);
}

class DoctorRepository implements IDoctorRepository {
  final PatientApiClient apiClient;

  DoctorRepository({required this.apiClient});

  @override
  Future<List<Doctor>> getDoctors() async {
    try {
      final data = await apiClient.getDoctors();
      return data.map((json) => Doctor.fromMap(json)).toList();
    } catch (e) {
      developer.log('Doctor fetch error: $e', name: 'DoctorRepository');
      return [];
    }
  }

  @override
  Future<Doctor?> getDoctorById(String id) async {
    final doctors = await getDoctors();
    try {
      return doctors.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Doctor>> getDoctorsByService(String serviceId) async {
    final doctors = await getDoctors();
    return doctors.where((d) => d.supportedServiceIds.contains(serviceId) || d.supportedServiceIds.isEmpty).toList();
  }
}
