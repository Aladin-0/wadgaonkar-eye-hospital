import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  String? _adminToken;

  Future<void> saveAdminToken(String token) async {
    _adminToken = token;
  }

  Future<String?> getAdminToken() async {
    return _adminToken;
  }

  Future<void> clearAdminToken() async {
    _adminToken = null;
  }
}
