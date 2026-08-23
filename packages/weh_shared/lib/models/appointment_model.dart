import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

enum BookingStatus {
  pendingPayment,
  confirmed,
  gracePeriod,
  checkedIn,
  completed,
  cancelled,
  noShow,
  expired,
  rescheduled;

  String get displayName {
    switch (this) {
      case BookingStatus.pendingPayment:
        return 'Pending Payment';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.gracePeriod:
        return 'Running Late';
      case BookingStatus.checkedIn:
        return 'Checked In';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.noShow:
        return 'No Show';
      case BookingStatus.expired:
        return 'Expired';
      case BookingStatus.rescheduled:
        return 'Rescheduled';
    }
  }

  bool get isActive => this == BookingStatus.confirmed ||
      this == BookingStatus.gracePeriod ||
      this == BookingStatus.pendingPayment;

  bool get isTerminal => this == BookingStatus.cancelled ||
      this == BookingStatus.completed ||
      this == BookingStatus.expired ||
      this == BookingStatus.noShow ||
      this == BookingStatus.checkedIn;

  static BookingStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'pending_payment':
      case 'pendingpayment':
        return BookingStatus.pendingPayment;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'graceperiod':
      case 'grace_period':
        return BookingStatus.gracePeriod;
      case 'checkedin':
      case 'checked_in':
        return BookingStatus.checkedIn;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      case 'noshow':
      case 'no_show':
        return BookingStatus.noShow;
      case 'expired':
        return BookingStatus.expired;
      case 'rescheduled':
        return BookingStatus.rescheduled;
      default:
        return BookingStatus.confirmed;
    }
  }
}

enum PaymentStatus {
  pending,
  paid,
  payAtHospitalDesk,
  refunded,
  failed;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Payment Pending';
      case PaymentStatus.paid:
        return 'Paid Online';
      case PaymentStatus.payAtHospitalDesk:
        return 'Pay at Hospital Desk';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.failed:
        return 'Payment Failed';
    }
  }

  static PaymentStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pay_at_hospital_desk':
      case 'payathospitaldesk':
      case 'desk':
        return PaymentStatus.payAtHospitalDesk;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }
}

/// Hospital Appointment Record with clinical metadata, signed anti-tamper QR payload, and payment verification.
class Appointment {
  static const String hospitalSalt = 'WEH_SECURE_AUTH_SALT_2026';

  final String id;
  final String appointmentCode; // e.g. "WEH-20260810-OPD-8821"
  final String patientUid;
  final String patientName;
  final String patientMobile;
  final int patientAge;
  final String? patientGender;
  final String patientId; // Hospital registered ID e.g. "WEH-2026-0045"
  final String doctorId;
  final String doctorName;
  final String doctorSpecialization;
  final String? doctorQualification;
  final String serviceId;
  final String serviceTitle;
  final DateTime appointmentDate;
  final DateTime slotStartTime;
  final DateTime slotEndTime;
  final double consultationFee;
  final BookingStatus bookingStatus;
  final PaymentStatus paymentStatus;
  final String? paymentMethod; // e.g. "razorpay_online", "hospital_desk"
  final String? paymentTransactionId;
  final String qrPayload;
  final String? qrSignature;
  final String? cancellationReason;
  final DateTime? gracePeriodStartedAt;
  final DateTime? expiresAt;
  final DateTime? checkedInAt;
  final bool requiresRescheduling;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.appointmentCode,
    required this.patientUid,
    required this.patientName,
    required this.patientMobile,
    required this.patientAge,
    this.patientGender,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialization,
    this.doctorQualification,
    required this.serviceId,
    required this.serviceTitle,
    required this.appointmentDate,
    required this.slotStartTime,
    required this.slotEndTime,
    required this.consultationFee,
    this.bookingStatus = BookingStatus.confirmed,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentMethod,
    this.paymentTransactionId,
    required this.qrPayload,
    this.qrSignature,
    this.cancellationReason,
    this.gracePeriodStartedAt,
    this.expiresAt,
    this.checkedInAt,
    this.requiresRescheduling = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computes a tamper-proof cryptographic SHA-256 signature for the appointment QR token
  static String computeSignature({
    required String appointmentCode,
    required String patientId,
    required String doctorId,
    required String dateStr,
    required double fee,
    String salt = hospitalSalt,
  }) {
    final rawMessage = '$appointmentCode|$patientId|$doctorId|$dateStr|${fee.toStringAsFixed(2)}|$salt';
    return sha256.convert(utf8.encode(rawMessage)).toString();
  }

  /// Verifies if a given QR payload has a valid authentic signature
  static bool verifyQrPayload(String rawPayload, {String salt = hospitalSalt}) {
    try {
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      final code = decoded['code'] as String?;
      final patientId = decoded['patient_id'] as String?;
      final doctorId = decoded['doctor_id'] as String? ?? '';
      final date = decoded['date'] as String?;
      final fee = (decoded['fee'] is num) ? (decoded['fee'] as num).toDouble() : 0.0;
      final signature = decoded['signature'] as String?;

      if (code == null || patientId == null || date == null || signature == null) {
        return false;
      }

      final expected = computeSignature(
        appointmentCode: code,
        patientId: patientId,
        doctorId: doctorId,
        dateStr: date,
        fee: fee,
        salt: salt,
      );

      return expected == signature;
    } catch (_) {
      return false;
    }
  }

  /// Factory creator for an appointment
  factory Appointment.create({
    required String id,
    required String patientUid,
    required String patientName,
    required String patientMobile,
    required int patientAge,
    String? patientGender,
    required String patientId,
    required String doctorId,
    required String doctorName,
    required String doctorSpecialization,
    String? doctorQualification,
    required String serviceId,
    required String serviceTitle,
    required DateTime appointmentDate,
    required DateTime slotStartTime,
    required DateTime slotEndTime,
    required double consultationFee,
    BookingStatus bookingStatus = BookingStatus.confirmed,
    PaymentStatus paymentStatus = PaymentStatus.pending,
    String? paymentMethod,
    String? paymentTransactionId,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(appointmentDate);
    final cleanApptId = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = cleanApptId.length >= 4
        ? cleanApptId.substring(cleanApptId.length - 4).toUpperCase()
        : '0001';
    final appointmentCode = 'WEH-$dateStr-OPD-$suffix';

    final sig = computeSignature(
      appointmentCode: appointmentCode,
      patientId: patientId,
      doctorId: doctorId,
      dateStr: DateFormat('yyyy-MM-dd').format(appointmentDate),
      fee: consultationFee,
    );

    final qrMap = {
      'hospital': 'Wadgaonkar Eye Hospital',
      'code': appointmentCode,
      'patient_id': patientId,
      'patient_name': patientName,
      'doctor': doctorName,
      'doctor_id': doctorId,
      'service': serviceTitle,
      'date': DateFormat('yyyy-MM-dd').format(appointmentDate),
      'time': '${DateFormat('hh:mm a').format(slotStartTime)} - ${DateFormat('hh:mm a').format(slotEndTime)}',
      'fee': consultationFee,
      'payment_status': paymentStatus.name,
      'status': bookingStatus.name,
      'signature': sig,
      'issued_at': now.toIso8601String(),
    };

    return Appointment(
      id: id,
      appointmentCode: appointmentCode,
      patientUid: patientUid,
      patientName: patientName.trim(),
      patientMobile: patientMobile.trim(),
      patientAge: patientAge,
      patientGender: patientGender,
      patientId: patientId,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialization: doctorSpecialization,
      doctorQualification: doctorQualification,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      appointmentDate: DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day),
      slotStartTime: slotStartTime,
      slotEndTime: slotEndTime,
      consultationFee: consultationFee,
      bookingStatus: bookingStatus,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      paymentTransactionId: paymentTransactionId,
      qrPayload: jsonEncode(qrMap),
      qrSignature: sig,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Formatted slot display string
  String get formattedSlotTime =>
      '${DateFormat('hh:mm a').format(slotStartTime)} - ${DateFormat('hh:mm a').format(slotEndTime)}';

  /// Formatted date string (e.g. "Mon, 10 Aug 2026")
  String get formattedDate => DateFormat('EEE, dd MMM yyyy').format(appointmentDate);

  /// Map serialization (Firestore & Generic REST)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentCode': appointmentCode,
      'patientUid': patientUid,
      'patientName': patientName,
      'patientMobile': patientMobile,
      'patientAge': patientAge,
      'patientGender': patientGender,
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorSpecialization': doctorSpecialization,
      'doctorQualification': doctorQualification,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'appointmentDate': appointmentDate.toIso8601String(),
      'slotStartTime': slotStartTime.toIso8601String(),
      'slotEndTime': slotEndTime.toIso8601String(),
      'consultationFee': consultationFee,
      'bookingStatus': bookingStatus.name,
      'paymentStatus': paymentStatus.name,
      'paymentMethod': paymentMethod,
      'paymentTransactionId': paymentTransactionId,
      'qrPayload': qrPayload,
      'qrSignature': qrSignature,
      'cancellationReason': cancellationReason,
      'gracePeriodStartedAt': gracePeriodStartedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'checkedInAt': checkedInAt?.toIso8601String(),
      'requiresRescheduling': requiresRescheduling,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Django REST Framework snake_case serialization
  Map<String, dynamic> toDjangoJson() {
    return {
      'id': id,
      'appointment_code': appointmentCode,
      'patient_uid': patientUid,
      'patient_name': patientName,
      'patient_mobile': patientMobile,
      'patient_age': patientAge,
      'patient_gender': patientGender,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'doctor_specialization': doctorSpecialization,
      'doctor_qualification': doctorQualification,
      'service_id': serviceId,
      'service_title': serviceTitle,
      'appointment_date': DateFormat('yyyy-MM-dd').format(appointmentDate),
      'slot_start_time': slotStartTime.toIso8601String(),
      'slot_end_time': slotEndTime.toIso8601String(),
      'consultation_fee': consultationFee,
      'booking_status': bookingStatus.name,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod,
      'payment_transaction_id': paymentTransactionId,
      'qr_payload': qrPayload,
      'qr_signature': qrSignature,
      'cancellation_reason': cancellationReason,
      'grace_period_started_at': gracePeriodStartedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'checked_in_at': checkedInAt?.toIso8601String(),
      'requires_rescheduling': requiresRescheduling,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Deserializer handling both camelCase and snake_case API responses
  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: (map['id'] ?? map['appointment_id'] ?? '') as String,
      appointmentCode: (map['appointmentCode'] ?? map['appointment_code'] ?? map['code'] ?? '') as String,
      patientUid: (map['patientUid'] ?? map['patient_uid'] ?? '') as String,
      patientName: (map['patientName'] ?? map['patient_name'] ?? '') as String,
      patientMobile: (map['patientMobile'] ?? map['patient_mobile'] ?? '') as String,
      patientAge: _parseInt(map['patientAge'] ?? map['patient_age']),
      patientGender: (map['patientGender'] ?? map['patient_gender']) as String?,
      patientId: (map['patientId'] ?? map['patient_id'] ?? '') as String,
      doctorId: (map['doctorId'] ?? map['doctor_id'] ?? '') as String,
      doctorName: (map['doctorName'] ?? map['doctor_name'] ?? '') as String,
      doctorSpecialization: (map['doctorSpecialization'] ?? map['doctor_specialization'] ?? '') as String,
      doctorQualification: (map['doctorQualification'] ?? map['doctor_qualification']) as String?,
      serviceId: (map['serviceId'] ?? map['service_id'] ?? '') as String,
      serviceTitle: (map['serviceTitle'] ?? map['service_title'] ?? '') as String,
      appointmentDate: _parseDate(map['appointmentDate'] ?? map['appointment_date']),
      slotStartTime: _parseDate(map['slotStartTime'] ?? map['slot_start_time']),
      slotEndTime: _parseDate(map['slotEndTime'] ?? map['slot_end_time']),
      consultationFee: _parseDouble(map['consultationFee'] ?? map['consultation_fee'] ?? map['fee']),
      bookingStatus: BookingStatus.fromString(map['bookingStatus'] ?? map['booking_status'] ?? map['status']),
      paymentStatus: PaymentStatus.fromString(map['paymentStatus'] ?? map['payment_status']),
      paymentMethod: (map['paymentMethod'] ?? map['payment_method']) as String?,
      paymentTransactionId: (map['paymentTransactionId'] ?? map['payment_transaction_id']) as String?,
      qrPayload: (map['qrPayload'] ?? map['qr_payload'] ?? '') as String,
      qrSignature: (map['qrSignature'] ?? map['qr_signature']) as String?,
      cancellationReason: (map['cancellationReason'] ?? map['cancellation_reason']) as String?,
      gracePeriodStartedAt: _parseDateOptional(map['gracePeriodStartedAt'] ?? map['grace_period_started_at']),
      expiresAt: _parseDateOptional(map['expiresAt'] ?? map['expires_at']),
      checkedInAt: _parseDateOptional(map['checkedInAt'] ?? map['checked_in_at']),
      requiresRescheduling: (map['requiresRescheduling'] ?? map['requires_rescheduling'] ?? false) as bool,
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  factory Appointment.fromDjangoJson(Map<String, dynamic> json) => Appointment.fromMap(json);
  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment.fromMap(json);
  Map<String, dynamic> toJson() => toDjangoJson();

  Appointment copyWith({
    String? id,
    String? appointmentCode,
    String? patientUid,
    String? patientName,
    String? patientMobile,
    int? patientAge,
    String? patientGender,
    String? patientId,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialization,
    String? doctorQualification,
    String? serviceId,
    String? serviceTitle,
    DateTime? appointmentDate,
    DateTime? slotStartTime,
    DateTime? slotEndTime,
    double? consultationFee,
    BookingStatus? bookingStatus,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    String? paymentTransactionId,
    String? qrPayload,
    String? qrSignature,
    String? cancellationReason,
    DateTime? gracePeriodStartedAt,
    DateTime? expiresAt,
    DateTime? checkedInAt,
    bool? requiresRescheduling,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      appointmentCode: appointmentCode ?? this.appointmentCode,
      patientUid: patientUid ?? this.patientUid,
      patientName: patientName ?? this.patientName,
      patientMobile: patientMobile ?? this.patientMobile,
      patientAge: patientAge ?? this.patientAge,
      patientGender: patientGender ?? this.patientGender,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialization: doctorSpecialization ?? this.doctorSpecialization,
      doctorQualification: doctorQualification ?? this.doctorQualification,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      slotStartTime: slotStartTime ?? this.slotStartTime,
      slotEndTime: slotEndTime ?? this.slotEndTime,
      consultationFee: consultationFee ?? this.consultationFee,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      qrPayload: qrPayload ?? this.qrPayload,
      qrSignature: qrSignature ?? this.qrSignature,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      gracePeriodStartedAt: gracePeriodStartedAt ?? this.gracePeriodStartedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      requiresRescheduling: requiresRescheduling ?? this.requiresRescheduling,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

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

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) {
      return DateTime.tryParse(val) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseDateOptional(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  @override
  String toString() => 'Appointment($appointmentCode, $doctorName, $formattedDate, $formattedSlotTime)';
}
