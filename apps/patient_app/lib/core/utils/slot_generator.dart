import 'package:weh_shared/weh_shared.dart';
import 'package:intl/intl.dart';

/// Dynamic Slot Generation Engine for hospital doctor schedules and OPD appointments.
/// Computes slots without hardcoded times, respecting doctor shifts, break intervals,
/// service durations, real-time clock, and existing booked appointments.
class SlotGenerator {
  /// Generates real-time availability slots for a doctor on a specific date.
  static List<TimeSlot> generateSlots({
    required Doctor doctor,
    required DateTime date,
    List<Appointment> existingAppointments = const [],
    HospitalService? service,
    DateTime? currentTime, // injectable for deterministic unit testing
  }) {
    final now = currentTime ?? DateTime.now();
    final targetDate = DateTime(date.year, date.month, date.day);

    // 1. Check if doctor is on duty on this day of week
    if (!doctor.workingDays.contains(date.weekday)) {
      return [];
    }

    // 2. Determine slot duration in minutes (service override or doctor default)
    final durationMinutes = service?.durationMinutesOverride ?? doctor.slotDurationMinutes;
    if (durationMinutes <= 0) return [];

    // 3. Parse doctor shift start and end
    final shiftStart = _parseTimeOnDate(targetDate, doctor.shiftStartTime, defaultHour: 9, defaultMinute: 0);
    final shiftEnd = _parseTimeOnDate(targetDate, doctor.shiftEndTime, defaultHour: 19, defaultMinute: 30);

    // 4. Parse break window if configured
    final breakStart = doctor.breakStartTime != null
        ? _parseTimeOnDate(targetDate, doctor.breakStartTime!, defaultHour: 13, defaultMinute: 30)
        : null;
    final breakEnd = doctor.breakEndTime != null
        ? _parseTimeOnDate(targetDate, doctor.breakEndTime!, defaultHour: 16, defaultMinute: 0)
        : null;

    final List<TimeSlot> slots = [];
    DateTime currentSlotStart = shiftStart;

    while (currentSlotStart.add(Duration(minutes: durationMinutes)).isBefore(shiftEnd) ||
        currentSlotStart.add(Duration(minutes: durationMinutes)).isAtSameMomentAs(shiftEnd)) {
      final currentSlotEnd = currentSlotStart.add(Duration(minutes: durationMinutes));
      final slotId =
          'slot_${doctor.id}_${DateFormat('yyyyMMdd_HHmm').format(currentSlotStart)}';

      // Check if slot falls in break interval
      bool isInBreak = false;
      if (breakStart != null && breakEnd != null) {
        if (currentSlotStart.isBefore(breakEnd) && currentSlotEnd.isAfter(breakStart)) {
          isInBreak = true;
        }
      }

      // Check if slot has passed
      final bool isPast = currentSlotStart.isBefore(now);

      // Check if slot conflicts with an active appointment for this doctor
      bool isBooked = false;
      for (final appt in existingAppointments) {
        if (appt.doctorId == doctor.id &&
            appt.bookingStatus != BookingStatus.cancelled &&
            appt.bookingStatus != BookingStatus.noShow) {
          // Check timestamp overlap
          if (currentSlotStart.isBefore(appt.slotEndTime) &&
              currentSlotEnd.isAfter(appt.slotStartTime)) {
            isBooked = true;
            break;
          }
        }
      }

      String? unavailabilityReason;
      if (isInBreak) {
        unavailabilityReason = 'Hospital OPD Break';
      } else if (isBooked) {
        unavailabilityReason = 'Already Booked';
      } else if (isPast) {
        unavailabilityReason = 'Time Elapsed';
      }

      final isAvailable = !isInBreak && !isBooked && !isPast && doctor.isActive;

      slots.add(TimeSlot(
        id: slotId,
        startTime: currentSlotStart,
        endTime: currentSlotEnd,
        doctorId: doctor.id,
        isAvailable: isAvailable,
        isBooked: isBooked,
        isPast: isPast,
        unavailabilityReason: unavailabilityReason,
      ));

      currentSlotStart = currentSlotEnd;
    }

    return slots;
  }

  static DateTime _parseTimeOnDate(DateTime baseDate, String timeStr,
      {required int defaultHour, required int defaultMinute}) {
    try {
      final parts = timeStr.trim().split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (_) {
      return DateTime(baseDate.year, baseDate.month, baseDate.day, defaultHour, defaultMinute);
    }
  }
}
