import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const String _keyAdminToken = 'weh_admin_jwt_token';

  Future<void> saveAdminToken(String token) async {
    await _storage.write(key: _keyAdminToken, value: token);
  }

  Future<String?> getAdminToken() async {
    return await _storage.read(key: _keyAdminToken);
  }

  Future<void> clearAdminToken() async {
    await _storage.delete(key: _keyAdminToken);
  }
}
