import 'package:weh_shared/weh_shared.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../core/utils/slot_generator.dart';

import '../data/repositories/appointment_repository.dart';
import '../data/repositories/doctor_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/services/payment_gateway_service.dart';

/// State management controller for doctor booking journey, dynamic slot computation,
/// payment orchestration, and appointment history.
class BookingProvider extends ChangeNotifier {
  final IDoctorRepository doctorRepository;
  final IServiceRepository serviceRepository;
  final IAppointmentRepository appointmentRepository;
  final IPaymentGatewayService paymentGatewayService;

  BookingProvider({
    required this.doctorRepository,
    required this.serviceRepository,
    required this.appointmentRepository,
    required this.paymentGatewayService,
  });

  // --- Catalog State ---
  List<Doctor> _doctors = [];
  List<HospitalService> _services = [];
  bool _isCatalogLoading = false;

  List<Doctor> get doctors => _doctors;
  List<HospitalService> get services => _services;
  bool get isCatalogLoading => _isCatalogLoading;

  // --- Active Booking Draft State ---
  Doctor? _selectedDoctor;
  HospitalService? _selectedService;
  DateTime _selectedDate = DateTime.now();
  List<TimeSlot> _availableSlots = [];
  TimeSlot? _selectedSlot;
  int _currentStep = 0; // 0: Doctor, 1: Service, 2: Slot, 3: Review/Pay

  Doctor? get selectedDoctor => _selectedDoctor;
  HospitalService? get selectedService => _selectedService;
  DateTime get selectedDate => _selectedDate;
  List<TimeSlot> get availableSlots => _availableSlots;
  TimeSlot? get selectedSlot => _selectedSlot;
  int get currentStep => _currentStep;

  // --- Booking Execution State ---
  bool _isBookingLoading = false;
  String? _errorMessage;
  Appointment? _lastConfirmedAppointment;
  PaymentOrder? _activePaymentOrder;

  bool get isBookingLoading => _isBookingLoading;
  String? get errorMessage => _errorMessage;
  Appointment? get lastConfirmedAppointment => _lastConfirmedAppointment;
  PaymentOrder? get activePaymentOrder => _activePaymentOrder;

  // --- History State ---
  List<Appointment> _patientAppointments = [];
  bool _isHistoryLoading = false;

  List<Appointment> get patientAppointments => _patientAppointments;
  bool get isHistoryLoading => _isHistoryLoading;

  List<Appointment> get upcomingAppointments => _patientAppointments
      .where((a) =>
          a.bookingStatus == BookingStatus.confirmed &&
          a.slotEndTime.isAfter(DateTime.now()))
      .toList();

  List<Appointment> get completedAppointments => _patientAppointments
      .where((a) =>
          a.bookingStatus == BookingStatus.completed ||
          (a.bookingStatus == BookingStatus.confirmed &&
              a.slotEndTime.isBefore(DateTime.now())))
      .toList();

  List<Appointment> get cancelledAppointments => _patientAppointments
      .where((a) =>
          a.bookingStatus == BookingStatus.cancelled ||
          a.bookingStatus == BookingStatus.noShow)
      .toList();

  /// Initialize catalogs and doctor schedules
  Future<void> initCatalog({String? patientUid}) async {
    _isCatalogLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        doctorRepository.getDoctors(),
        serviceRepository.getServices(),
      ]);

      _doctors = results[0] as List<Doctor>;
      _services = results[1] as List<HospitalService>;

      // Auto select first doctor and service if not already selected
      if (_selectedDoctor == null && _doctors.isNotEmpty) {
        _selectedDoctor = _doctors.first;
      }
      if (_selectedService == null && _services.isNotEmpty) {
        _selectedService = _services.first;
      }

      await _refreshSlots();

      if (patientUid != null && patientUid.isNotEmpty) {
        await loadPatientAppointments(patientUid);
      }
    } catch (e) {
      developer.log('Catalog load error: $e', name: 'BookingProvider');
      _errorMessage = 'Failed to load doctor schedules and services.';
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// Select Doctor
  Future<void> selectDoctor(Doctor doctor) async {
    _selectedDoctor = doctor;
    _selectedSlot = null;
    await _refreshSlots();
    notifyListeners();
  }

  /// Select Service
  Future<void> selectService(HospitalService service) async {
    _selectedService = service;
    _selectedSlot = null;
    await _refreshSlots();
    notifyListeners();
  }

  /// Select Appointment Date
  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedSlot = null;
    await _refreshSlots();
    notifyListeners();
  }

  /// Select specific TimeSlot
  void selectSlot(TimeSlot slot) {
    if (slot.isSelectable) {
      _selectedSlot = slot;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Recomputes dynamic slots based on doctor, service, selected date & booked collisions
  Future<void> _refreshSlots() async {
    if (_selectedDoctor == null) {
      _availableSlots = [];
      return;
    }

    try {
      final existingAppointments = await appointmentRepository.getDoctorAppointmentsForDate(
        doctorId: _selectedDoctor!.id,
        date: _selectedDate,
      );

      _availableSlots = SlotGenerator.generateSlots(
        doctor: _selectedDoctor!,
        date: _selectedDate,
        existingAppointments: existingAppointments,
        service: _selectedService,
      );
    } catch (e) {
      developer.log('Error refreshing slots: $e', name: 'BookingProvider');
      _availableSlots = [];
    }
  }

  /// Step navigation
  void setStep(int step) {
    _currentStep = step;
    _errorMessage = null;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Reset the active booking draft
  void resetDraft() {
    _currentStep = 0;
    _selectedSlot = null;
    _errorMessage = null;
    _lastConfirmedAppointment = null;
    _activePaymentOrder = null;
    _selectedDate = DateTime.now();
    if (_doctors.isNotEmpty) _selectedDoctor = _doctors.first;
    if (_services.isNotEmpty) _selectedService = _services.first;
    _refreshSlots();
    notifyListeners();
  }

  /// Execute "Pay at Hospital Reception Desk" Booking
  Future<Appointment?> bookPayAtDesk({required UserProfile profile}) async {
    if (_selectedDoctor == null || _selectedService == null || _selectedSlot == null) {
      _errorMessage = 'Please complete doctor, service, and slot selection.';
      notifyListeners();
      return null;
    }

    _isBookingLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final apptId = 'appt_${DateTime.now().millisecondsSinceEpoch}';
      final draft = Appointment.create(
        id: apptId,
        patientUid: profile.uid,
        patientName: profile.fullName,
        patientMobile: profile.mobileNumber,
        patientAge: profile.age,
        patientGender: profile.gender,
        patientId: profile.patientId.isNotEmpty ? profile.patientId : 'WEH-${profile.uid}',
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        doctorSpecialization: _selectedDoctor!.specialization,
        doctorQualification: _selectedDoctor!.qualification,
        serviceId: _selectedService!.id,
        serviceTitle: _selectedService!.title,
        appointmentDate: _selectedDate,
        slotStartTime: _selectedSlot!.startTime,
        slotEndTime: _selectedSlot!.endTime,
        consultationFee: _selectedDoctor!.consultationFee,
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.payAtHospitalDesk,
        paymentMethod: 'hospital_desk',
      );

      final confirmed = await appointmentRepository.bookPayAtHospitalDesk(appointment: draft);
      _lastConfirmedAppointment = confirmed;
      await loadPatientAppointments(profile.uid);
      await _refreshSlots();
      return confirmed;
    } catch (e) {
      developer.log('Booking desk failure: $e', name: 'BookingProvider');
      _errorMessage = 'Unable to complete appointment booking. Please try again.';
      return null;
    } finally {
      _isBookingLoading = false;
      notifyListeners();
    }
  }

  /// Prepare and verify Online Payment (e.g. Razorpay)
  Future<Appointment?> bookWithOnlinePayment({
    required UserProfile profile,
    required String paymentTransactionId,
    required String signature,
  }) async {
    if (_selectedDoctor == null || _selectedService == null || _selectedSlot == null) {
      _errorMessage = 'Please complete doctor, service, and slot selection.';
      notifyListeners();
      return null;
    }

    _isBookingLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final apptId = 'appt_${DateTime.now().millisecondsSinceEpoch}';
      final fee = _selectedDoctor!.consultationFee;

      // 1. Create Gateway Order
      final order = await paymentGatewayService.createOrder(
        amount: fee,
        appointmentId: apptId,
        patientName: profile.fullName,
        patientMobile: profile.mobileNumber,
        patientEmail: profile.email ?? 'patient@wadgaonkareye.in',
      );
      _activePaymentOrder = order;

      // 2. Verify Payment Signature
      final verification = await paymentGatewayService.verifyPayment(
        orderId: order.orderId,
        paymentId: paymentTransactionId,
        signature: signature,
      );

      if (!verification.isSuccess) {
        _errorMessage = verification.errorMessage ?? 'Payment verification failed.';
        return null;
      }

      // 3. Create Draft & Confirm Booking
      final draft = Appointment.create(
        id: apptId,
        patientUid: profile.uid,
        patientName: profile.fullName,
        patientMobile: profile.mobileNumber,
        patientAge: profile.age,
        patientGender: profile.gender,
        patientId: profile.patientId.isNotEmpty ? profile.patientId : 'WEH-${profile.uid}',
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        doctorSpecialization: _selectedDoctor!.specialization,
        doctorQualification: _selectedDoctor!.qualification,
        serviceId: _selectedService!.id,
        serviceTitle: _selectedService!.title,
        appointmentDate: _selectedDate,
        slotStartTime: _selectedSlot!.startTime,
        slotEndTime: _selectedSlot!.endTime,
        consultationFee: fee,
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: verification.paymentMethod ?? 'razorpay_online',
        paymentTransactionId: verification.transactionId,
      );

      final confirmed = await appointmentRepository.confirmBooking(
        appointmentId: (await appointmentRepository.createPendingBooking(draft)).id,
        paymentTransactionId: verification.transactionId ?? paymentTransactionId,
        paymentMethod: verification.paymentMethod ?? 'razorpay_online',
      );

      _lastConfirmedAppointment = confirmed;
      await loadPatientAppointments(profile.uid);
      await _refreshSlots();
      return confirmed;
    } catch (e) {
      developer.log('Online booking failure: $e', name: 'BookingProvider');
      _errorMessage = 'Online payment could not be processed. Please try again or choose pay at desk.';
      return null;
    } finally {
      _isBookingLoading = false;
      notifyListeners();
    }
  }

  /// Load user's appointment history
  Future<void> loadPatientAppointments(String patientUid) async {
    _isHistoryLoading = true;
    notifyListeners();

    try {
      _patientAppointments = await appointmentRepository.getPatientAppointments(patientUid);
    } catch (e) {
      developer.log('Error loading patient appointments: $e', name: 'BookingProvider');
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  /// Cancel appointment
  Future<bool> cancelAppointment({
    required String appointmentId,
    required String reason,
    required String patientUid,
  }) async {
    try {
      await appointmentRepository.cancelAppointment(
        appointmentId: appointmentId,
        reason: reason,
      );
      await loadPatientAppointments(patientUid);
      await _refreshSlots();
      return true;
    } catch (e) {
      developer.log('Cancel appointment failure: $e', name: 'BookingProvider');
      return false;
    }
  }

  /// Reschedule appointment hook
  Future<bool> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    required DateTime newSlotStartTime,
    required DateTime newSlotEndTime,
    required String patientUid,
    String? reason,
  }) async {
    try {
      await appointmentRepository.rescheduleAppointment(
        appointmentId: appointmentId,
        newDate: newDate,
        newSlotStartTime: newSlotStartTime,
        newSlotEndTime: newSlotEndTime,
        reason: reason,
      );
      await loadPatientAppointments(patientUid);
      await _refreshSlots();
      return true;
    } catch (e) {
      developer.log('Reschedule appointment failure: $e', name: 'BookingProvider');
      return false;
    }
  }
}
