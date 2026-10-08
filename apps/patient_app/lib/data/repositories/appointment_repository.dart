import 'package:weh_shared/weh_shared.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import '../../core/errors/app_exception.dart';

import '../services/patient_api_client.dart';
import '../services/storage_service.dart';

abstract class IAppointmentRepository {
  Future<Appointment> createPendingBooking(Appointment appointment);
  Future<Appointment> confirmBooking({
    required String appointmentId,
    required String paymentTransactionId,
    required String paymentMethod,
  });
  Future<Appointment> bookPayAtHospitalDesk({required Appointment appointment});
  Future<List<Appointment>> getPatientAppointments(String patientUid);
  Future<Appointment?> getAppointmentById(String appointmentId);
  Future<List<Appointment>> getDoctorAppointmentsForDate({
    required String doctorId,
    required DateTime date,
  });
  Future<List<TimeSlot>> getSlots({
    required String doctorId,
    required DateTime date,
    String? serviceId,
  });
  Future<Appointment> cancelAppointment({
    required String appointmentId,
    required String reason,
  });
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    required DateTime newSlotStartTime,
    required DateTime newSlotEndTime,
    String? reason,
  });
}

class AppointmentRepository implements IAppointmentRepository {
  final StorageService storageService;
  final PatientApiClient apiClient;

  AppointmentRepository({
    required this.storageService,
    required this.apiClient,
  });

  @override
  Future<Appointment> createPendingBooking(Appointment appointment) async {
    try {
      final requestData = {
        'id': appointment.id,
        'patient_uid': appointment.patientUid,
        'patient_name': appointment.patientName,
        'patient_mobile': appointment.patientMobile,
        'patient_age': appointment.patientAge,
        'patient_gender': appointment.patientGender,
        'patient_id': appointment.patientId,
        'doctor_id': appointment.doctorId,
        'doctor_name': appointment.doctorName,
        'service_id': appointment.serviceId,
        'service_title': appointment.serviceTitle,
        'appointment_date': appointment.appointmentDate.toIso8601String(),
        'slot_start_time': appointment.slotStartTime.toUtc().toIso8601String(),
        'slot_end_time': appointment.slotEndTime.toUtc().toIso8601String(),
        'consultation_fee': appointment.consultationFee,
        'booking_status': appointment.bookingStatus.name,
        'payment_status': appointment.paymentStatus.name,
        'payment_method': appointment.paymentMethod,
        'payment_transaction_id': appointment.paymentTransactionId,
        'appointment_code': appointment.appointmentCode,
        'qr_payload': appointment.qrPayload,
        'qr_signature': appointment.qrSignature,
      };

      final response = await apiClient.createAppointment(requestData);
      final remoteAppt = Appointment.fromMap(response);

      await storageService.saveAppointment(remoteAppt);
      return remoteAppt;
    } catch (e) {
      developer.log('Error creating pending booking via API: $e', name: 'AppointmentRepository', error: e);
      // Fallback: save locally
      await storageService.saveAppointment(appointment);
      return appointment;
    }
  }

  @override
  Future<Appointment> confirmBooking({
    required String appointmentId,
    required String paymentTransactionId,
    required String paymentMethod,
  }) async {
    try {
      final requestData = {
        'booking_status': BookingStatus.confirmed.name,
        'payment_status': PaymentStatus.paid.name,
        'payment_method': paymentMethod,
        'payment_transaction_id': paymentTransactionId,
      };
      
      final response = await apiClient.updateAppointmentStatus(appointmentId, requestData);
      final confirmed = Appointment.fromMap(response);
      
      await storageService.saveAppointment(confirmed);
      return confirmed;
    } catch (e) {
      developer.log('Error confirming booking via API: $e', name: 'AppointmentRepository');
      // Fallback to local
      final existing = await getAppointmentById(appointmentId);
      if (existing == null) throw ProfileException('Appointment not found');
      
      final confirmed = existing.copyWith(
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: paymentMethod,
        paymentTransactionId: paymentTransactionId,
        updatedAt: DateTime.now(),
      );
      await storageService.saveAppointment(confirmed);
      return confirmed;
    }
  }

  @override
  Future<Appointment> bookPayAtHospitalDesk({required Appointment appointment}) async {
    try {
      final requestData = {
        'booking_status': BookingStatus.confirmed.name,
        'payment_status': PaymentStatus.payAtHospitalDesk.name,
        'payment_method': 'hospital_desk',
      };
      
      final response = await apiClient.updateAppointmentStatus(appointment.id, requestData);
      final deskBooking = Appointment.fromMap(response);
      
      await storageService.saveAppointment(deskBooking);
      return deskBooking;
    } catch (e) {
      developer.log('Error updating desk booking via API: $e', name: 'AppointmentRepository');
      // Fallback to local
      final deskBooking = appointment.copyWith(
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.payAtHospitalDesk,
        paymentMethod: 'hospital_desk',
        updatedAt: DateTime.now(),
      );
      await storageService.saveAppointment(deskBooking);
      return deskBooking;
    }
  }

  @override
  Future<List<Appointment>> getPatientAppointments(String patientUid) async {
    try {
      final responseList = await apiClient.getPatientAppointments(patientUid);
      final list = responseList.map((json) => Appointment.fromMap(json)).toList();
      
      await storageService.saveAppointments(list);
      list.sort((a, b) => b.slotStartTime.compareTo(a.slotStartTime));
      return list;
    } catch (e) {
      developer.log('Error fetching patient appointments from API: $e', name: 'AppointmentRepository');
      final list = storageService
          .getAppointments()
          .where((a) => a.patientUid == patientUid)
          .toList();
      list.sort((a, b) => b.slotStartTime.compareTo(a.slotStartTime));
      return list;
    }
  }

  @override
  Future<Appointment?> getAppointmentById(String appointmentId) async {
    final list = storageService.getAppointments();
    try {
      return list.firstWhere((a) => a.id == appointmentId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Appointment>> getDoctorAppointmentsForDate({
    required String doctorId,
    required DateTime date,
  }) async {
    // Currently used for local fallbacks if needed.
    final localList = storageService.getAppointments().where((a) {
      return a.doctorId == doctorId &&
          a.appointmentDate.year == date.year &&
          a.appointmentDate.month == date.month &&
          a.appointmentDate.day == date.day &&
          a.bookingStatus != BookingStatus.cancelled;
    }).toList();
    return localList;
  }

  @override
  Future<List<TimeSlot>> getSlots({
    required String doctorId,
    required DateTime date,
    String? serviceId,
  }) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final responseList = await apiClient.getSlots(doctorId, dateStr, serviceId: serviceId);
      return responseList.map((json) => TimeSlot.fromMap(json)).toList();
    } catch (e) {
      developer.log('Error fetching slots from API: $e', name: 'AppointmentRepository');
      return [];
    }
  }

  @override
  Future<Appointment> cancelAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    try {
      final requestData = {
        'booking_status': BookingStatus.cancelled.name,
        'cancellation_reason': reason,
      };
      
      final response = await apiClient.updateAppointmentStatus(appointmentId, requestData);
      final cancelled = Appointment.fromMap(response);
      
      await storageService.saveAppointment(cancelled);
      return cancelled;
    } catch (e) {
      developer.log('API cancel error: $e', name: 'AppointmentRepository');
      // Fallback local
      final existing = await getAppointmentById(appointmentId);
      if (existing == null) throw ProfileException('Appointment not found');
      
      final cancelled = existing.copyWith(
        bookingStatus: BookingStatus.cancelled,
        cancellationReason: reason,
        updatedAt: DateTime.now(),
      );
      await storageService.saveAppointment(cancelled);
      return cancelled;
    }
  }

  @override
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    required DateTime newSlotStartTime,
    required DateTime newSlotEndTime,
    String? reason,
  }) async {
    final existing = await getAppointmentById(appointmentId);
    if (existing == null) {
      throw ProfileException('Appointment not found with ID: $appointmentId');
    }

    final dateFormatted = DateFormat('yyyy-MM-dd').format(newDate);
    final sig = Appointment.computeSignature(
      appointmentCode: existing.appointmentCode,
      patientId: existing.patientId,
      doctorId: existing.doctorId,
      dateStr: dateFormatted,
      fee: existing.consultationFee,
    );

    final updatedQrMap = {
      'hospital': 'Wadgaonkar Eye Hospital',
      'code': existing.appointmentCode,
      'patient_id': existing.patientId,
      'patient_name': existing.patientName,
      'doctor': existing.doctorName,
      'doctor_id': existing.doctorId,
      'service': existing.serviceTitle,
      'date': dateFormatted,
      'time': '${DateFormat('hh:mm a').format(newSlotStartTime)} - ${DateFormat('hh:mm a').format(newSlotEndTime)}',
      'fee': existing.consultationFee,
      'payment_status': existing.paymentStatus.name,
      'status': BookingStatus.confirmed.name,
      'signature': sig,
      'rescheduled': true,
      'issued_at': DateTime.now().toIso8601String(),
    };

    try {
      // Use the dedicated reschedule endpoint which properly resets booking_status to 'confirmed'
      final requestData = {
        'new_appointment_date': DateFormat('yyyy-MM-dd').format(newDate),
        'new_slot_start_time': newSlotStartTime.toUtc().toIso8601String(),
        'new_slot_end_time': newSlotEndTime.toUtc().toIso8601String(),
      };
      
      final response = await apiClient.rescheduleAppointment(appointmentId, requestData);
      final rescheduled = Appointment.fromMap(response);
      
      await storageService.saveAppointment(rescheduled);
      return rescheduled;
    } catch (e) {
      developer.log('API reschedule error: $e', name: 'AppointmentRepository');
      // Fallback local
      final rescheduled = existing.copyWith(
        appointmentDate: DateTime(newDate.year, newDate.month, newDate.day),
        slotStartTime: newSlotStartTime,
        slotEndTime: newSlotEndTime,
        bookingStatus: BookingStatus.confirmed,
        qrPayload: jsonEncode(updatedQrMap),
        qrSignature: sig,
        updatedAt: DateTime.now(),
      );
      await storageService.saveAppointment(rescheduled);
      return rescheduled;
    }
  }
}
