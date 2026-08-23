import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weh_shared/weh_shared.dart';

import 'data/services/admin_api_client.dart';
import 'data/services/secure_storage_service.dart';
import 'state/admin_provider.dart';
import 'ui/screens/admin_login_screen.dart';
import 'ui/screens/admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = SecureStorageService();
  final adminApiClient = AdminApiClient(secureStorage);
  final isLoggedIn = await secureStorage.getAdminToken() != null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AdminProvider(adminApiClient: adminApiClient),
        ),
      ],
      child: WEHAdminApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class WEHAdminApp extends StatelessWidget {
  final bool isLoggedIn;

  const WEHAdminApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WEH Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn ? const AdminShell() : const AdminLoginScreen(),
    );
  }
}
