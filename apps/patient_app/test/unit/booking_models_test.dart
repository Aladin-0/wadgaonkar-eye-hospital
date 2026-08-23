import 'package:weh_shared/weh_shared.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 Data Models & Django Mapping Tests', () {
    test('Doctor model dual serialization to Django REST snake_case & fromMap', () {
      const doctor = Doctor(
        id: 'doc_anand',
        name: 'Dr. Anand Wadgaonkar',
        qualification: 'MS Ophthalmology',
        specialization: 'Cataract Surgeon',
        experienceYears: 28,
        consultationFee: 600.0,
        slotDurationMinutes: 20,
        workingDays: [1, 2, 3, 4, 5, 6],
        shiftStartTime: '09:00',
        shiftEndTime: '19:30',
        breakStartTime: '13:30',
        breakEndTime: '16:00',
        supportedServiceIds: ['srv_cataract'],
        bio: 'Senior microsurgeon',
      );

      final djangoJson = doctor.toDjangoJson();
      expect(djangoJson['experience_years'], 28);
      expect(djangoJson['consultation_fee'], 600.0);
      expect(djangoJson['slot_duration_minutes'], 20);
      expect(djangoJson['shift_start_time'], '09:00');
      expect(djangoJson['break_start_time'], '13:30');

      // Reconstruct from Django API response
      final fromDjango = Doctor.fromDjangoJson(djangoJson);
      expect(fromDjango.id, 'doc_anand');
      expect(fromDjango.name, 'Dr. Anand Wadgaonkar');
      expect(fromDjango.experienceYears, 28);
      expect(fromDjango.consultationFee, 600.0);
    });

    test('HospitalService model dual serialization to Django REST & fromMap', () {
      const service = HospitalService(
        id: 'srv_cataract',
        title: 'Cataract Consultation',
        department: 'Cataract Clinic',
        description: 'IOL selection',
        baseFee: 600.0,
        durationMinutesOverride: 25,
        iconCode: 'remove_red_eye',
      );

      final djangoJson = service.toDjangoJson();
      expect(djangoJson['base_fee'], 600.0);
      expect(djangoJson['duration_minutes_override'], 25);
      expect(djangoJson['icon_code'], 'remove_red_eye');

      final fromDjango = HospitalService.fromDjangoJson(djangoJson);
      expect(fromDjango.id, 'srv_cataract');
      expect(fromDjango.baseFee, 600.0);
      expect(fromDjango.durationMinutesOverride, 25);
    });

    test('Appointment model generates clean code, authentic QR payload, and valid crypto signature', () {
      final appt = Appointment.create(
        id: 'appt_9941',
        patientUid: 'uid_test_1',
        patientName: 'Ramesh Kulkarni',
        patientMobile: '9822012345',
        patientAge: 52,
        patientGender: 'Male',
        patientId: 'WEH-2026-0042',
        doctorId: 'doc_anand',
        doctorName: 'Dr. Anand Wadgaonkar',
        doctorSpecialization: 'Cataract Surgeon',
        serviceId: 'srv_cataract',
        serviceTitle: 'Cataract & Premium IOL Evaluation',
        appointmentDate: DateTime(2026, 8, 10),
        slotStartTime: DateTime(2026, 8, 10, 10, 0),
        slotEndTime: DateTime(2026, 8, 10, 10, 20),
        consultationFee: 600.0,
      );

      // Verify Appointment Code format
      expect(appt.appointmentCode, contains('WEH-20260810-OPD-9941'));

      // Verify QR payload is valid JSON and contains anti-tamper signature
      final qrData = jsonDecode(appt.qrPayload) as Map<String, dynamic>;
      expect(qrData['hospital'], 'Wadgaonkar Eye Hospital');
      expect(qrData['patient_id'], 'WEH-2026-0042');
      expect(qrData['patient_name'], 'Ramesh Kulkarni');
      expect(qrData['doctor'], 'Dr. Anand Wadgaonkar');
      expect(qrData['code'], appt.appointmentCode);
      expect(qrData['signature'], isNotNull);

      // Test QR payload authenticity verification
      expect(Appointment.verifyQrPayload(appt.qrPayload), isTrue);

      // Tampered QR payload should fail verification
      final tamperedData = Map<String, dynamic>.from(qrData);
      tamperedData['fee'] = 0.0; // Tampered free consultation attempt
      expect(Appointment.verifyQrPayload(jsonEncode(tamperedData)), isFalse);

      // Test Django REST Serialization
      final djangoJson = appt.toDjangoJson();
      expect(djangoJson['appointment_code'], appt.appointmentCode);
      expect(djangoJson['patient_name'], 'Ramesh Kulkarni');
      expect(djangoJson['consultation_fee'], 600.0);
      expect(djangoJson['booking_status'], 'confirmed');
      expect(djangoJson['qr_signature'], isNotNull);

      final fromDjango = Appointment.fromDjangoJson(djangoJson);
      expect(fromDjango.appointmentCode, appt.appointmentCode);
      expect(fromDjango.consultationFee, 600.0);
      expect(fromDjango.bookingStatus, BookingStatus.confirmed);
    });

    test('PaymentOrder model dual serialization to Django REST & fromMap', () {
      final order = PaymentOrder(
        orderId: 'order_rzp_12345',
        appointmentId: 'appt_9941',
        amount: 600.0,
        currency: 'INR',
        gatewayName: 'Razorpay',
        gatewayOrderId: 'order_Kj98aX1',
        status: 'created',
        patientName: 'Ramesh Kulkarni',
        patientMobile: '9822012345',
        patientEmail: 'ramesh@example.com',
        notes: {'service': 'Cataract'},
        createdAt: DateTime(2026, 8, 10, 9, 30),
      );

      final djangoJson = order.toDjangoJson();
      expect(djangoJson['order_id'], 'order_rzp_12345');
      expect(djangoJson['appointment_id'], 'appt_9941');
      expect(djangoJson['amount'], 600.0);
      expect(djangoJson['gateway_name'], 'Razorpay');

      final fromDjango = PaymentOrder.fromDjangoJson(djangoJson);
      expect(fromDjango.orderId, 'order_rzp_12345');
      expect(fromDjango.appointmentId, 'appt_9941');
      expect(fromDjango.amount, 600.0);
      expect(fromDjango.currency, 'INR');
    });

    test('TimeSlot period categorization', () {
      final morningSlot = TimeSlot(
        id: '1',
        startTime: DateTime(2026, 8, 10, 10, 0),
        endTime: DateTime(2026, 8, 10, 10, 20),
        doctorId: 'doc_1',
      );
      final afternoonSlot = TimeSlot(
        id: '2',
        startTime: DateTime(2026, 8, 10, 14, 0),
        endTime: DateTime(2026, 8, 10, 14, 20),
        doctorId: 'doc_1',
      );
      final eveningSlot = TimeSlot(
        id: '3',
        startTime: DateTime(2026, 8, 10, 17, 30),
        endTime: DateTime(2026, 8, 10, 17, 50),
        doctorId: 'doc_1',
      );

      expect(morningSlot.period, SlotPeriod.morning);
      expect(afternoonSlot.period, SlotPeriod.afternoon);
      expect(eveningSlot.period, SlotPeriod.evening);
    });
  });
}
