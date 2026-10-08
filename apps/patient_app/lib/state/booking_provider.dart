import 'package:weh_shared/weh_shared.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

import '../data/repositories/appointment_repository.dart';
import '../data/repositories/doctor_repository.dart';
import '../data/repositories/service_repository.dart';
import '../data/services/payment_gateway_service.dart';
import '../data/services/local_notification_service.dart';

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

  // Slot cache: key = "doctorId_YYYY-MM-DD_serviceId"
  final Map<String, List<TimeSlot>> _slotCache = {};
  bool _isSlotsLoading = false;
  bool get isSlotsLoading => _isSlotsLoading;

  Doctor? get selectedDoctor => _selectedDoctor;
  HospitalService? get selectedService => _selectedService;
  DateTime get selectedDate => _selectedDate;
  List<TimeSlot> get availableSlots => _availableSlots;
  TimeSlot? get selectedSlot => _selectedSlot;
  int get currentStep => _currentStep;

  Appointment? _appointmentToReschedule;
  Appointment? get appointmentToReschedule => _appointmentToReschedule;

  // --- Fee Calculation State ---
  double _finalFee = 0.0;
  double _originalFee = 0.0;
  bool _isDiscountApplied = false;
  String _discountMessage = '';

  double get finalFee => _finalFee;
  double get originalFee => _originalFee;
  bool get isDiscountApplied => _isDiscountApplied;
  String get discountMessage => _discountMessage;

  void setRescheduleAppointment(Appointment? appt) {
    _appointmentToReschedule = appt;
    if (appt != null) {
      try {
        _selectedDoctor = _doctors.firstWhere((d) => d.id == appt.doctorId);
        _selectedService = _services.firstWhere((s) => s.id == appt.serviceId);
      } catch (_) {
        // Fallback if not found
      }
      _currentStep = 2; // Skip to date/time selection
      _refreshSlots();
    }
    notifyListeners();
  }

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
          (a.bookingStatus == BookingStatus.confirmed ||
           a.bookingStatus == BookingStatus.checkedIn ||
           a.bookingStatus == BookingStatus.gracePeriod) &&
          a.slotEndTime.isAfter(DateTime.now()))
      .toList();

  List<Appointment> get completedAppointments => _patientAppointments
      .where((a) =>
          a.bookingStatus == BookingStatus.completed ||
          ((a.bookingStatus == BookingStatus.confirmed || 
            a.bookingStatus == BookingStatus.checkedIn || 
            a.bookingStatus == BookingStatus.gracePeriod) &&
              a.slotEndTime.isBefore(DateTime.now())))
      .toList();

  List<Appointment> get cancelledAppointments => _patientAppointments
      .where((a) =>
          a.bookingStatus == BookingStatus.cancelled ||
          a.bookingStatus == BookingStatus.noShow ||
          a.bookingStatus == BookingStatus.expired ||
          a.bookingStatus == BookingStatus.rescheduled ||
          a.bookingStatus == BookingStatus.needsReschedule)
      .toList();

  List<Appointment> get needsRescheduleAppointments => _patientAppointments
      .where((a) => a.requiresRescheduling)
      .toList();

  /// Initialize catalogs and doctor schedules
  Future<void> initCatalog({String? patientUid}) async {
    _isCatalogLoading = true;
    notifyListeners();

    try {
      // Fetch doctors and services in parallel
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

      // Run slots refresh + history load in parallel for speed
      await Future.wait([
        _refreshSlots(),
        if (patientUid != null && patientUid.isNotEmpty)
          loadPatientAppointments(patientUid)
        else
          Future.value(),
      ]);

      // Background prefetch next 3 days so tapping dates feels instant
      _prefetchNextDays(3);

    } catch (e) {
      developer.log('Catalog load error: $e', name: 'BookingProvider');
      _errorMessage = 'Failed to load doctor schedules and services.';
    } finally {
      _isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// Silently prefetch slots for next N days to make date switching instant
  void _prefetchNextDays(int days) {
    if (_selectedDoctor == null) return;
    final now = DateTime.now();
    for (int i = 1; i <= days; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      final cacheKey = _slotCacheKey(date);
      if (!_slotCache.containsKey(cacheKey)) {
        appointmentRepository
            .getSlots(
              doctorId: _selectedDoctor!.id,
              date: date,
              serviceId: _selectedService?.id,
            )
            .then((slots) => _slotCache[cacheKey] = slots)
            .catchError((_) {});
      }
    }
  }

  String _slotCacheKey(DateTime date) {
    final doctorId = _selectedDoctor?.id ?? '';
    final serviceId = _selectedService?.id ?? '';
    return '${doctorId}_${date.year}-${date.month}-${date.day}_$serviceId';
  }

  /// Select Doctor — clears slot cache for this doctor, refetches
  Future<void> selectDoctor(Doctor doctor) async {
    if (_selectedDoctor?.id == doctor.id) return; // no-op if same doctor
    _selectedDoctor = doctor;
    _selectedSlot = null;
    _slotCache.clear(); // clear cache: new doctor = new schedule
    notifyListeners(); // immediate UI update
    await _refreshSlots();
    notifyListeners();
    _prefetchNextDays(3); // prefetch upcoming days
  }

  /// Select Service
  Future<void> selectService(HospitalService service) async {
    if (_selectedService?.id == service.id) return;
    _selectedService = service;
    _selectedSlot = null;
    _slotCache.clear(); // service change affects fee/slot availability
    notifyListeners();
    await _refreshSlots();
    notifyListeners();
  }

  /// Select Appointment Date — uses cache for instant switching
  void selectDate(DateTime date) {
    final normalised = DateTime(date.year, date.month, date.day);
    if (_selectedDate == normalised) return;
    _selectedDate = normalised;
    _selectedSlot = null;

    final cacheKey = _slotCacheKey(normalised);
    if (_slotCache.containsKey(cacheKey)) {
      // Instant: serve from cache, no network call
      _availableSlots = _slotCache[cacheKey]!;
      notifyListeners();
    } else {
      // Not cached yet: fetch and cache
      notifyListeners();
      _refreshSlots();
    }
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

    final cacheKey = _slotCacheKey(_selectedDate);

    // Return from cache immediately if available
    if (_slotCache.containsKey(cacheKey)) {
      _availableSlots = _slotCache[cacheKey]!;
      return;
    }

    try {
      final slots = await appointmentRepository.getSlots(
        doctorId: _selectedDoctor!.id,
        date: _selectedDate,
        serviceId: _selectedService?.id,
      );
      _slotCache[cacheKey] = slots; // save to cache
      _availableSlots = slots;
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

  /// Reset the booking state
  void resetDraft() {
    _selectedDoctor = null;
    _selectedService = null;
    _selectedDate = DateTime.now();
    _selectedSlot = null;
    _availableSlots = [];
    _currentStep = 0;
    _errorMessage = null;
    _isBookingLoading = false;
    _activePaymentOrder = null;
    _appointmentToReschedule = null;
    
    _finalFee = 0.0;
    _originalFee = 0.0;
    _isDiscountApplied = false;
    _discountMessage = '';
    
    if (_doctors.isNotEmpty) _selectedDoctor = _doctors.first;
    if (_services.isNotEmpty) _selectedService = _services.first;
    _refreshSlots();
    notifyListeners();
  }

  Future<void> calculateFinalFee(String patientUid) async {
    if (_selectedService == null) return;
    
    _originalFee = _selectedService!.baseFee;
    _finalFee = _originalFee;
    _isDiscountApplied = false;
    _discountMessage = '';
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    try {
      final res = await serviceRepository.calculateFee(
        serviceId: _selectedService!.id, 
        patientUid: patientUid, 
        date: dateStr,
      );
      if (res != null) {
        _originalFee = (res['original_fee'] as num?)?.toDouble() ?? _originalFee;
        _finalFee = (res['final_fee'] as num?)?.toDouble() ?? _finalFee;
        _isDiscountApplied = (res['discount_applied'] as bool?) ?? false;
        _discountMessage = (res['message'] as String?) ?? '';
      }
    } catch (e) {
      developer.log('Error calculating fee: $e');
    }
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
        consultationFee: _finalFee > 0 ? _finalFee : _selectedService!.baseFee,
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.payAtHospitalDesk,
        paymentMethod: 'hospital_desk',
      );

      // First create the pending appointment on the backend
      final pendingAppt = await appointmentRepository.createPendingBooking(draft);
      
      // Then confirm it as a desk payment
      final confirmed = await appointmentRepository.bookPayAtHospitalDesk(appointment: pendingAppt);
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

  Future<Appointment?> createPendingOnlineBooking({required UserProfile profile}) async {
    if (_selectedDoctor == null || _selectedService == null || _selectedSlot == null) {
      _errorMessage = 'Please complete all selection steps.';
      notifyListeners();
      return null;
    }
    _isBookingLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final fee = _finalFee > 0 ? _finalFee : _selectedService!.baseFee;
      final draft = Appointment.create(
        id: 'appt_${DateTime.now().millisecondsSinceEpoch}',
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
        bookingStatus: BookingStatus.pendingPayment,
        paymentStatus: PaymentStatus.pending,
        paymentMethod: 'razorpay_online',
      );
      return await appointmentRepository.createPendingBooking(draft);
    } catch (e) {
      developer.log('Create pending failed: $e', name: 'BookingProvider');
      _errorMessage = 'Could not initiate booking. Please try again.';
      _isBookingLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Appointment?> confirmOnlineBooking({
    required String appointmentId,
    required String paymentTransactionId,
  }) async {
    try {
      final confirmed = await appointmentRepository.confirmBooking(
        appointmentId: appointmentId,
        paymentTransactionId: paymentTransactionId,
        paymentMethod: 'razorpay_online',
      );
      _lastConfirmedAppointment = confirmed;
      notifyListeners();
      return confirmed;
    } catch (e) {
      developer.log('Confirm booking failed: $e', name: 'BookingProvider');
      _errorMessage = 'Booking confirmation failed. Please contact support.';
      return null;
    } finally {
      _isBookingLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelPendingBooking(String appointmentId) async {
    try {
      await appointmentRepository.cancelAppointment(
        appointmentId: appointmentId,
        reason: 'Payment failed or cancelled by user.',
      );
    } catch (_) {}
    _isBookingLoading = false;
    notifyListeners();
  }
  /// Load user's appointment history
  Future<void> loadPatientAppointments(String patientUid) async {
    _isHistoryLoading = true;
    notifyListeners();

    try {
      _patientAppointments = await appointmentRepository.getPatientAppointments(patientUid);
      _updateScheduledNotifications();
    } catch (e) {
      developer.log('Error loading patient appointments: $e', name: 'BookingProvider');
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateScheduledNotifications() async {
    try {
      final service = LocalNotificationService();
      await service.cancelAll();
      for (final appt in upcomingAppointments) {
        final reminderTime = appt.slotStartTime.subtract(const Duration(minutes: 15));
        developer.log('Evaluating upcoming appt ${appt.id} at ${appt.slotStartTime}, reminderTime: $reminderTime', name: 'BookingProvider');
        await service.scheduleAppointmentCountdown(appt);
      }
    } catch (e) {
      developer.log('Error scheduling local notifications: $e', name: 'BookingProvider');
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
      final confirmed = await appointmentRepository.rescheduleAppointment(
        appointmentId: appointmentId,
        newDate: newDate,
        newSlotStartTime: newSlotStartTime,
        newSlotEndTime: newSlotEndTime,
        reason: reason,
      );
      _lastConfirmedAppointment = confirmed;
      await loadPatientAppointments(patientUid);
      await _refreshSlots();
      return true;
    } catch (e) {
      developer.log('Reschedule appointment failure: $e', name: 'BookingProvider');
      return false;
    }
  }
}
