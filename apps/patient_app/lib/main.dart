import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/repositories/appointment_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/doctor_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/service_repository.dart';
import 'data/services/firebase_service.dart';
import 'data/services/payment_gateway_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/patient_api_client.dart';
import 'state/auth_provider.dart';
import 'state/booking_provider.dart';
import 'state/profile_provider.dart';
import 'ui/screens/splash_screen.dart';
import 'data/services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred portrait orientation for mobile clinical app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Firebase safely
  await FirebaseService.initialize();

  // Initialize Local Storage Service
  final storageService = await StorageService.init();

  // Initialize Local Notification Service
  await LocalNotificationService().init();

  // Instantiate Repositories & Services
  final patientApiClient = PatientApiClient();
  final authRepository = AuthRepository(storageService: storageService);
  final profileRepository = ProfileRepository(storageService: storageService);
  final doctorRepository = DoctorRepository(apiClient: patientApiClient);
  final serviceRepository = ServiceRepository(apiClient: patientApiClient);
  final appointmentRepository = AppointmentRepository(
    storageService: storageService,
    apiClient: patientApiClient,
  );
  final paymentGatewayService = PaymentGatewayService();

  // Build the root widget tree
  Widget app = MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storageService),
      Provider<IAuthRepository>.value(value: authRepository),
      Provider<IProfileRepository>.value(value: profileRepository),
      Provider<IDoctorRepository>.value(value: doctorRepository),
      Provider<IServiceRepository>.value(value: serviceRepository),
      Provider<IAppointmentRepository>.value(value: appointmentRepository),
      Provider<IPaymentGatewayService>.value(value: paymentGatewayService),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authRepository: authRepository),
      ),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(profileRepository: profileRepository),
      ),
      ChangeNotifierProvider<BookingProvider>(
        create: (_) => BookingProvider(
          doctorRepository: doctorRepository,
          serviceRepository: serviceRepository,
          appointmentRepository: appointmentRepository,
          paymentGatewayService: paymentGatewayService,
        ),
      ),
    ],
    child: const WadgaonkarEyeHospitalApp(),
  );

  runApp(app);
}

class WadgaonkarEyeHospitalApp extends StatelessWidget {
  const WadgaonkarEyeHospitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
