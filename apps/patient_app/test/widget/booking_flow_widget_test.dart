import 'package:weh_shared/weh_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wadgaonkar_eye_hospital/data/repositories/appointment_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/auth_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/doctor_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/profile_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/service_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/services/payment_gateway_service.dart';
import 'package:wadgaonkar_eye_hospital/data/services/storage_service.dart';
import 'package:wadgaonkar_eye_hospital/data/services/patient_api_client.dart';
import 'package:wadgaonkar_eye_hospital/state/auth_provider.dart';
import 'package:wadgaonkar_eye_hospital/state/booking_provider.dart';

import 'package:wadgaonkar_eye_hospital/state/profile_provider.dart';
import 'package:wadgaonkar_eye_hospital/ui/screens/booking/appointment_receipt_screen.dart';
import 'package:wadgaonkar_eye_hospital/ui/screens/booking/booking_flow_screen.dart';

class FakePatientApiClient extends PatientApiClient {
  @override
  Future<List<dynamic>> getDoctors() async {
    return [
      {
        'id': 'doc_anand_wadgaonkar',
        'name': 'Dr. Anand Wadgaonkar',
        'qualification': 'MBBS, MS',
        'specialization': 'Senior Cataract Surgeon',
        'experienceYears': 28,
        'consultationFee': 600.0,
        'slotDurationMinutes': 20,
        'workingDays': [1, 2, 3, 4, 5, 6],
        'shiftStartTime': '09:00',
        'shiftEndTime': '19:30',
        'breakStartTime': '13:30',
        'breakEndTime': '16:00',
        'supportedServiceIds': ['srv_cataract'],
        'bio': 'Test bio'
      },
      {
        'id': 'doc_pradnya_wadgaonkar',
        'name': 'Dr. Pradnya Wadgaonkar',
        'qualification': 'MBBS',
        'specialization': 'Glaucoma Specialist',
        'experienceYears': 24,
        'consultationFee': 600.0,
        'slotDurationMinutes': 20,
        'workingDays': [1, 2, 3, 4, 5, 6],
        'shiftStartTime': '09:00',
        'shiftEndTime': '19:30',
        'breakStartTime': '13:30',
        'breakEndTime': '16:00',
        'supportedServiceIds': ['srv_glaucoma'],
        'bio': 'Test bio'
      },
    ];
  }

  @override
  Future<List<dynamic>> getServices() async {
    return [
      {
        'id': 'srv_cataract',
        'title': 'Cataract Consultation',
        'department': 'General OPD',
        'description': 'Test description',
        'baseFee': 600.0,
        'iconCode': 'remove_red_eye',
        'preparationInstructions': []
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> data) async {
    data['id'] = 'test_id_123';
    return data;
  }

  @override
  Future<Map<String, dynamic>> updateAppointmentStatus(String appointmentId, Map<String, dynamic> data) async {
    return data;
  }
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late DoctorRepository doctorRepository;
  late ServiceRepository serviceRepository;
  late AppointmentRepository appointmentRepository;
  late PaymentGatewayService paymentGatewayService;
  late AuthRepository authRepository;
  late ProfileRepository profileRepository;
  late PatientApiClient patientApiClient;

  final testProfile = UserProfile(
    uid: 'patient_widget_test',
    fullName: 'Ananya Sharma',
    mobileNumber: '9876543210',
    email: 'ananya@example.com',
    age: 32,
    gender: 'Female',
    patientId: 'WEH-2026-0099',
    city: 'Ahmednagar',
    isProfileComplete: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  const authUser = AuthUser(
    uid: 'patient_widget_test',
    email: 'ananya@example.com',
    displayName: 'Ananya Sharma',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);

    await storageService.saveUserProfile(testProfile);
    await storageService.saveAuthUser(authUser);

    patientApiClient = FakePatientApiClient();
    doctorRepository = DoctorRepository(apiClient: patientApiClient);
    serviceRepository = ServiceRepository(apiClient: patientApiClient);
    appointmentRepository = AppointmentRepository(
      storageService: storageService,
      apiClient: patientApiClient,
    );
    paymentGatewayService = PaymentGatewayService();
    authRepository = AuthRepository(storageService: storageService);
    profileRepository = ProfileRepository(storageService: storageService);
  });

  Widget buildTestApp(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(profileRepository: profileRepository)..loadProfile(authUser),
        ),
        ChangeNotifierProvider<BookingProvider>(
          create: (_) => BookingProvider(
            doctorRepository: doctorRepository,
            serviceRepository: serviceRepository,
            appointmentRepository: appointmentRepository,
            paymentGatewayService: paymentGatewayService,
          )..initCatalog(patientUid: 'patient_widget_test'),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  testWidgets('BookingFlowScreen renders doctor list and step progress bar', (tester) async {
    await tester.pumpWidget(buildTestApp(const BookingFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Select Doctor'), findsOneWidget);
    expect(find.text('Choose Eye Specialist Consultant'), findsOneWidget);
    expect(find.text('Dr. Anand Wadgaonkar'), findsOneWidget);
    expect(find.text('Dr. Pradnya Wadgaonkar'), findsOneWidget);
    expect(find.text('Next: Select Service'), findsOneWidget);
  });

  testWidgets('AppointmentReceiptScreen displays pass and QR code', (tester) async {
    final appt = Appointment.create(
      id: 'test_pass_123',
      patientUid: testProfile.uid,
      patientName: testProfile.fullName,
      patientMobile: testProfile.mobileNumber,
      patientAge: testProfile.age,
      patientId: testProfile.patientId,
      doctorId: 'doc_anand_wadgaonkar',
      doctorName: 'Dr. Anand Wadgaonkar',
      doctorSpecialization: 'Senior Cataract Surgeon',
      serviceId: 'srv_cataract',
      serviceTitle: 'Cataract & Premium IOL Consultation',
      appointmentDate: DateTime(2026, 8, 12),
      slotStartTime: DateTime(2026, 8, 12, 11, 0),
      slotEndTime: DateTime(2026, 8, 12, 11, 20),
      consultationFee: 600.0,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppointmentReceiptScreen(appointment: appt),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Booking Confirmed!'), findsOneWidget);
    expect(find.text(appt.appointmentCode), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
