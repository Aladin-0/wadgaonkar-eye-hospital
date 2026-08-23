import 'package:weh_shared/weh_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wadgaonkar_eye_hospital/core/utils/slot_generator.dart';

void main() {
  group('SlotGenerator Dynamic Engine Tests', () {
    const testDoctor = Doctor(
      id: 'doc_test',
      name: 'Dr. Anand Wadgaonkar',
      qualification: 'MBBS, MS',
      specialization: 'Senior Cataract Surgeon',
      experienceYears: 28,
      consultationFee: 600.0,
      slotDurationMinutes: 20,
      workingDays: [1, 2, 3, 4, 5, 6], // Mon - Sat (Sunday = 7 not included)
      shiftStartTime: '09:00',
      shiftEndTime: '12:00', // Short shift for testing: 09:00 to 12:00 (9 slots of 20 min)
      breakStartTime: '10:00',
      breakEndTime: '10:40', // 2 slots in break: 10:00-10:20, 10:20-10:40
    );

    // Pick a Monday (weekday == 1)
    final mondayDate = DateTime(2026, 8, 10);
    // Pick a Sunday (weekday == 7)
    final sundayDate = DateTime(2026, 8, 16);

    test('Doctor off on non-working days returns 0 slots', () {
      final slots = SlotGenerator.generateSlots(
        doctor: testDoctor,
        date: sundayDate,
        currentTime: DateTime(2026, 8, 16, 8, 0),
      );

      expect(slots.isEmpty, isTrue);
    });

    test('Generates correct interval slots respecting shift and break times', () {
      final slots = SlotGenerator.generateSlots(
        doctor: testDoctor,
        date: mondayDate,
        currentTime: DateTime(2026, 8, 10, 8, 0), // current time before shift
      );

      // 09:00 to 12:00 with 20min intervals = 9 total slots:
      // 09:00, 09:20, 09:40, 10:00, 10:20, 10:40, 11:00, 11:20, 11:40
      expect(slots.length, 9);

      // Check break slots (10:00 - 10:40)
      final breakSlot1 = slots.firstWhere((s) => s.startTime.hour == 10 && s.startTime.minute == 0);
      final breakSlot2 = slots.firstWhere((s) => s.startTime.hour == 10 && s.startTime.minute == 20);
      final activeSlot = slots.firstWhere((s) => s.startTime.hour == 9 && s.startTime.minute == 0);

      expect(breakSlot1.isAvailable, isFalse);
      expect(breakSlot1.unavailabilityReason, 'Hospital OPD Break');
      expect(breakSlot2.isAvailable, isFalse);
      expect(activeSlot.isAvailable, isTrue);
      expect(activeSlot.isSelectable, isTrue);
    });

    test('Marks elapsed slots as past when current time advances', () {
      final slots = SlotGenerator.generateSlots(
        doctor: testDoctor,
        date: mondayDate,
        currentTime: DateTime(2026, 8, 10, 9, 30), // 09:30 AM
      );

      final slot900 = slots.firstWhere((s) => s.startTime.hour == 9 && s.startTime.minute == 0);
      final slot920 = slots.firstWhere((s) => s.startTime.hour == 9 && s.startTime.minute == 20);
      final slot940 = slots.firstWhere((s) => s.startTime.hour == 9 && s.startTime.minute == 40);

      expect(slot900.isPast, isTrue);
      expect(slot900.isSelectable, isFalse);
      expect(slot920.isPast, isTrue);
      expect(slot920.isSelectable, isFalse);
      expect(slot940.isPast, isFalse);
      expect(slot940.isSelectable, isTrue);
    });

    test('Marks slot as booked when overlapping with active appointment', () {
      final existingAppt = Appointment.create(
        id: 'appt_123',
        patientUid: 'user_1',
        patientName: 'Test Patient',
        patientMobile: '9876543210',
        patientAge: 35,
        patientId: 'WEH-001',
        doctorId: testDoctor.id,
        doctorName: testDoctor.name,
        doctorSpecialization: testDoctor.specialization,
        serviceId: 'srv_cataract',
        serviceTitle: 'Cataract Checkup',
        appointmentDate: mondayDate,
        slotStartTime: DateTime(2026, 8, 10, 11, 0),
        slotEndTime: DateTime(2026, 8, 10, 11, 20),
        consultationFee: 600.0,
      );

      final slots = SlotGenerator.generateSlots(
        doctor: testDoctor,
        date: mondayDate,
        existingAppointments: [existingAppt],
        currentTime: DateTime(2026, 8, 10, 8, 0),
      );

      final bookedSlot = slots.firstWhere((s) => s.startTime.hour == 11 && s.startTime.minute == 0);
      final freeSlot = slots.firstWhere((s) => s.startTime.hour == 11 && s.startTime.minute == 20);

      expect(bookedSlot.isBooked, isTrue);
      expect(bookedSlot.isSelectable, isFalse);
      expect(bookedSlot.unavailabilityReason, 'Already Booked');
      expect(freeSlot.isBooked, isFalse);
      expect(freeSlot.isSelectable, isTrue);
    });

    test('Respects service duration override (30 min instead of 20 min)', () {
      const longService = HospitalService(
        id: 'srv_lasik_long',
        title: 'LASIK Workup',
        department: 'Refractive',
        description: 'Detailed workup',
        baseFee: 800.0,
        durationMinutesOverride: 30,
      );

      final slots = SlotGenerator.generateSlots(
        doctor: testDoctor,
        date: mondayDate,
        service: longService,
        currentTime: DateTime(2026, 8, 10, 8, 0),
      );

      // 09:00 to 12:00 with 30 min intervals = 6 total slots:
      // 09:00, 09:30, 10:00, 10:30, 11:00, 11:30
      expect(slots.length, 6);
      expect(slots[0].displayTime, '09:00 AM');
      expect(slots[1].displayTime, '09:30 AM');
    });
  });
}
