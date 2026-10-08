import 'package:intl/intl.dart';

/// Time slot entity computed dynamically by SlotGenerator.
class TimeSlot {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String doctorId;
  final bool isAvailable;
  final bool isBooked;
  final bool isPast;
  final String? unavailabilityReason; // e.g. "OPD Break", "Already Booked", "Shift Ended"
  final int? unavailabilityId; // Backend ID for deletion

  const TimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.doctorId,
    this.isAvailable = true,
    this.isBooked = false,
    this.isPast = false,
    this.unavailabilityReason,
    this.unavailabilityId,
  });

  /// Formatted start time e.g. "09:20 AM"
  String get displayTime => DateFormat('hh:mm a').format(startTime);

  /// Formatted range e.g. "09:20 AM - 09:40 AM"
  String get displayRange =>
      '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}';

  /// Whether the user can tap and select this slot
  bool get isSelectable => isAvailable && !isBooked && !isPast;

  /// Period category: Morning (before 12 PM), Afternoon (12-4 PM), Evening (4 PM onwards)
  SlotPeriod get period {
    final hour = startTime.hour;
    if (hour < 12) return SlotPeriod.morning;
    if (hour < 16) return SlotPeriod.afternoon;
    return SlotPeriod.evening;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'doctorId': doctorId,
      'isAvailable': isAvailable,
      'isBooked': isBooked,
      'isPast': isPast,
      'unavailabilityReason': unavailabilityReason,
      'unavailabilityId': unavailabilityId,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'] as String? ?? '',
      startTime: DateTime.parse(map['startTime'] as String).toLocal(),
      endTime: DateTime.parse(map['endTime'] as String).toLocal(),
      doctorId: map['doctorId'] as String? ?? '',
      isAvailable: map['isAvailable'] as bool? ?? true,
      isBooked: map['isBooked'] as bool? ?? false,
      isPast: map['isPast'] as bool? ?? false,
      unavailabilityReason: map['unavailabilityReason'] as String?,
      unavailabilityId: map['unavailabilityId'] as int?,
    );
  }

  @override
  String toString() => 'TimeSlot($displayRange, selectable: $isSelectable)';
}

enum SlotPeriod {
  morning,
  afternoon,
  evening,
}
