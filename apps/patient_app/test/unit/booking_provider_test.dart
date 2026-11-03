import 'package:weh_shared/weh_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wadgaonkar_eye_hospital/data/repositories/appointment_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/doctor_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/repositories/service_repository.dart';
import 'package:wadgaonkar_eye_hospital/data/services/payment_gateway_service.dart';
import 'package:wadgaonkar_eye_hospital/data/services/storage_service.dart';
import 'package:wadgaonkar_eye_hospital/data/services/patient_api_client.dart';
import 'package:wadgaonkar_eye_hospital/state/booking_provider.dart';

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
  Future<List<dynamic>> getSlots(String doctorId, String date, {String? serviceId}) async {
    final start = DateTime.parse('${date}T10:00:00');
    return [
      TimeSlot(
        id: 'slot_$date',
        startTime: start,
        endTime: start.add(const Duration(minutes: 20)),
        doctorId: doctorId,
      ).toMap(),
    ];
  }

  @override
  Future<List<dynamic>> getPatientAppointments(String patientUid) async {
    throw Exception('Simulated network error to force local cache read');
  }

  @override
  Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> data) async {
    data['id'] = 'test_id_123';
    return data;
  }

  @override
  Future<Map<String, dynamic>> updateAppointmentStatus(String appointmentId, Map<String, dynamic> data) async {
    data['id'] = appointmentId;
    // mock the data to be valid Appointment format based on what's passed in
    // For bookPayAtDesk, it sends booking_status and payment_status, we need to return a full appointment.
    // Actually the Appointment.fromMap() will try to parse all fields.
    // In our test, if it fails to parse from map, it falls back to saving locally!
    // So throwing an exception or returning junk data is fine because the fallback handles it gracefully.
    throw Exception('Simulated network error, fallback to local save');
  }
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late DoctorRepository doctorRepository;
  late ServiceRepository serviceRepository;
  late AppointmentRepository appointmentRepository;
  late PaymentGatewayService paymentGatewayService;
  late BookingProvider bookingProvider;
  late PatientApiClient patientApiClient;

  final testProfile = UserProfile(
    uid: 'patient_101',
    fullName: 'Sunil Joshi',
    mobileNumber: '9822123456',
    email: 'sunil@example.com',
    age: 48,
    gender: 'Male',
    patientId: 'WEH-2026-0101',
    city: 'Ahmednagar',
    isProfileComplete: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);

    patientApiClient = FakePatientApiClient();
    doctorRepository = DoctorRepository(apiClient: patientApiClient);
    serviceRepository = ServiceRepository(apiClient: patientApiClient);
    appointmentRepository = AppointmentRepository(
      storageService: storageService,
      apiClient: patientApiClient,
    );
    paymentGatewayService = PaymentGatewayService();

    bookingProvider = BookingProvider(
      doctorRepository: doctorRepository,
      serviceRepository: serviceRepository,
      appointmentRepository: appointmentRepository,
      paymentGatewayService: paymentGatewayService,
    );
  });

  group('BookingProvider State & Workflow Tests', () {
    test('initCatalog loads doctors and services', () async {
      await bookingProvider.initCatalog();

      expect(bookingProvider.doctors.isNotEmpty, isTrue);
      expect(bookingProvider.services.isNotEmpty, isTrue);
      expect(bookingProvider.selectedDoctor, isNotNull);
      expect(bookingProvider.selectedService, isNotNull);
    });

    test('Booking pay-at-desk creates appointment and clears draft', () async {
      await bookingProvider.initCatalog();

      // Ensure we pick a future working weekday (Monday to Saturday)
      DateTime futureDate = DateTime.now().add(const Duration(days: 2));
      if (futureDate.weekday == 7) {
        futureDate = futureDate.add(const Duration(days: 1)); // Skip Sunday
      }
      bookingProvider.selectDate(futureDate);
      // selectDate is fire-and-forget; wait for the slot fetch to finish.
      await Future.delayed(const Duration(milliseconds: 50));

      // Pick a weekday slot
      final selectableSlots = bookingProvider.availableSlots.where((s) => s.isSelectable).toList();
      expect(selectableSlots.isNotEmpty, isTrue);

      bookingProvider.selectSlot(selectableSlots.first);
      expect(bookingProvider.selectedSlot, selectableSlots.first);

      final appt = await bookingProvider.bookPayAtDesk(profile: testProfile);

      expect(appt, isNotNull);
      expect(appt!.patientUid, testProfile.uid);
      expect(appt.patientName, testProfile.fullName);
      expect(appt.paymentMethod, 'hospital_desk');
      expect(bookingProvider.lastConfirmedAppointment, isNotNull);

      // Check upcoming appointments
      expect(bookingProvider.patientAppointments.length, 1);
    });

    test('Step navigation functions correctly', () {
      expect(bookingProvider.currentStep, 0);
      bookingProvider.nextStep();
      expect(bookingProvider.currentStep, 1);
      bookingProvider.nextStep();
      expect(bookingProvider.currentStep, 2);
      bookingProvider.prevStep();
      expect(bookingProvider.currentStep, 1);
    });
  });
}
