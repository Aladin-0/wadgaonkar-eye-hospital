import 'package:intl/intl.dart';

/// Doctor data model with clinical qualifications, OPD schedule, and consultation fees.
/// Supports both Firestore and Django REST Framework JSON serialization.
class Doctor {
  final String id;
  final String name;
  final String qualification;
  final String specialization;
  final int experienceYears;
  final String? profileImageUrl;
  final double consultationFee;
  final int slotDurationMinutes;
  final List<int> workingDays; // DateTime weekday numbers (1 = Mon, 7 = Sun)
  final String shiftStartTime; // Format "HH:mm" (e.g. "09:00")
  final String shiftEndTime; // Format "HH:mm" (e.g. "19:30")
  final String? breakStartTime; // Format "HH:mm" (e.g. "13:30")
  final String? breakEndTime; // Format "HH:mm" (e.g. "16:00")
  final bool isActive;
  final List<String> supportedServiceIds;
  final String? bio;

  const Doctor({
    required this.id,
    required this.name,
    required this.qualification,
    required this.specialization,
    required this.experienceYears,
    this.profileImageUrl,
    required this.consultationFee,
    this.slotDurationMinutes = 20,
    this.workingDays = const [1, 2, 3, 4, 5, 6], // Mon - Sat default
    this.shiftStartTime = '09:00',
    this.shiftEndTime = '19:30',
    this.breakStartTime = '13:30',
    this.breakEndTime = '16:00',
    this.isActive = true,
    this.supportedServiceIds = const [],
    this.bio,
  });

  /// Map serialization for Firestore / General REST
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'qualification': qualification,
      'specialization': specialization,
      'experienceYears': experienceYears,
      'profileImageUrl': profileImageUrl,
      'consultationFee': consultationFee,
      'slotDurationMinutes': slotDurationMinutes,
      'workingDays': workingDays,
      'shiftStartTime': shiftStartTime,
      'shiftEndTime': shiftEndTime,
      'breakStartTime': breakStartTime,
      'breakEndTime': breakEndTime,
      'isActive': isActive,
      'supportedServiceIds': supportedServiceIds,
      'bio': bio,
    };
  }

  /// Django REST Framework snake_case serialization
  Map<String, dynamic> toDjangoJson() {
    return {
      'id': id,
      'name': name,
      'qualification': qualification,
      'specialization': specialization,
      'experience_years': experienceYears,
      'profile_image_url': profileImageUrl,
      'consultation_fee': consultationFee,
      'slot_duration_minutes': slotDurationMinutes,
      'working_days': workingDays,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'break_start_time': breakStartTime,
      'break_end_time': breakEndTime,
      'is_active': isActive,
      'supported_service_ids': supportedServiceIds,
      'bio': bio,
    };
  }

  /// Deserializer handling both camelCase and snake_case API responses
  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: (map['id'] ?? map['doctor_id'] ?? '') as String,
      name: (map['name'] ?? map['doctor_name'] ?? '') as String,
      qualification: (map['qualification'] ?? '') as String,
      specialization: (map['specialization'] ?? map['specialty'] ?? '') as String,
      experienceYears: _parseInt(map['experienceYears'] ?? map['experience_years']),
      profileImageUrl: (map['profileImageUrl'] ?? map['profile_image_url'] ?? map['photo_url']) as String?,
      consultationFee: _parseDouble(map['consultationFee'] ?? map['consultation_fee'] ?? map['fee']),
      slotDurationMinutes: _parseInt(map['slotDurationMinutes'] ?? map['slot_duration_minutes'] ?? 20),
      workingDays: _parseDaysList(map['workingDays'] ?? map['working_days']),
      shiftStartTime: (map['shiftStartTime'] ?? map['shift_start_time'] ?? '09:00') as String,
      shiftEndTime: (map['shiftEndTime'] ?? map['shift_end_time'] ?? '19:30') as String,
      breakStartTime: (map['breakStartTime'] ?? map['break_start_time']) as String?,
      breakEndTime: (map['breakEndTime'] ?? map['break_end_time']) as String?,
      isActive: (map['isActive'] ?? map['is_active'] ?? true) as bool,
      supportedServiceIds: _parseStringList(map['supportedServiceIds'] ?? map['supported_service_ids']),
      bio: map['bio'] as String?,
    );
  }

  factory Doctor.fromDjangoJson(Map<String, dynamic> json) => Doctor.fromMap(json);
  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor.fromMap(json);
  Map<String, dynamic> toJson() => toDjangoJson();

  static int _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic val) {
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  static List<int> _parseDaysList(dynamic val) {
    if (val is List) {
      return val.map((e) => _parseInt(e)).where((e) => e > 0).toList();
    }
    return const [1, 2, 3, 4, 5, 6];
  }

  static List<String> _parseStringList(dynamic val) {
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _formatTime12h(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return time24;
    }
  }

  String get formattedShiftStartTime => _formatTime12h(shiftStartTime);
  String get formattedShiftEndTime => _formatTime12h(shiftEndTime);
  String get formattedBreakStartTime => breakStartTime != null ? _formatTime12h(breakStartTime!) : '';
  String get formattedBreakEndTime => breakEndTime != null ? _formatTime12h(breakEndTime!) : '';

  @override
  String toString() => 'Doctor($name, $specialization, Fee: ₹$consultationFee)';
}
