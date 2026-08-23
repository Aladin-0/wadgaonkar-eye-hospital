import 'package:weh_shared/weh_shared.dart';
import 'dart:developer' as developer;
import '../services/patient_api_client.dart';

abstract class IServiceRepository {
  Future<List<HospitalService>> getServices();
  Future<HospitalService?> getServiceById(String id);
}

class ServiceRepository implements IServiceRepository {
  final PatientApiClient apiClient;

  ServiceRepository({required this.apiClient});

  @override
  Future<List<HospitalService>> getServices() async {
    try {
      final data = await apiClient.getServices();
      return data.map((json) => HospitalService.fromMap(json)).toList();
    } catch (e) {
      developer.log('Services fetch error: $e', name: 'ServiceRepository');
      return [];
    }
  }

  @override
  Future<HospitalService?> getServiceById(String id) async {
    final services = await getServices();
    try {
      return services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
