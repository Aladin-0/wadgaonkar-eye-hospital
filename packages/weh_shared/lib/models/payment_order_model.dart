/// Payment order entity representing an initialized PhonePe gateway checkout order.
/// Supports Firestore and Django REST Framework snake_case serialization.
class PaymentOrder {
  final String orderId;
  final String appointmentId;
  final double amount;
  final String currency; // "INR"
  final String gatewayName; // "PhonePe"
  final String? merchantTransactionId; // unique ID we generate and send TO PhonePe
  final String? gatewayOrderId;        // PhonePe's own transactionId returned in callback
  final String status; // "created", "paid", "failed", "pending"
  final String patientName;
  final String patientMobile;
  final String patientEmail;
  final Map<String, String>? notes;
  final DateTime createdAt;

  const PaymentOrder({
    required this.orderId,
    required this.appointmentId,
    required this.amount,
    this.currency = 'INR',
    this.gatewayName = 'PhonePe',
    this.merchantTransactionId,
    this.gatewayOrderId,
    this.status = 'created',
    required this.patientName,
    required this.patientMobile,
    required this.patientEmail,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'appointmentId': appointmentId,
      'amount': amount,
      'currency': currency,
      'gatewayName': gatewayName,
      'merchantTransactionId': merchantTransactionId,
      'gatewayOrderId': gatewayOrderId,
      'status': status,
      'patientName': patientName,
      'patientMobile': patientMobile,
      'patientEmail': patientEmail,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toDjangoJson() {
    return {
      'order_id': orderId,
      'appointment_id': appointmentId,
      'amount': amount,
      'currency': currency,
      'gateway_name': gatewayName,
      'merchant_transaction_id': merchantTransactionId,
      'gateway_order_id': gatewayOrderId,
      'status': status,
      'patient_name': patientName,
      'patient_mobile': patientMobile,
      'patient_email': patientEmail,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PaymentOrder.fromMap(Map<String, dynamic> map) {
    return PaymentOrder(
      orderId: (map['orderId'] ?? map['order_id'] ?? '') as String,
      appointmentId: (map['appointmentId'] ?? map['appointment_id'] ?? '') as String,
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : (double.tryParse(map['amount']?.toString() ?? '0.0') ?? 0.0),
      currency: (map['currency'] ?? 'INR') as String,
      gatewayName: (map['gatewayName'] ?? map['gateway_name'] ?? 'PhonePe') as String,
      merchantTransactionId: (map['merchantTransactionId'] ?? map['merchant_transaction_id']) as String?,
      gatewayOrderId: (map['gatewayOrderId'] ?? map['gateway_order_id']) as String?,
      status: (map['status'] ?? 'created') as String,
      patientName: (map['patientName'] ?? map['patient_name'] ?? '') as String,
      patientMobile: (map['patientMobile'] ?? map['patient_mobile'] ?? '') as String,
      patientEmail: (map['patientEmail'] ?? map['patient_email'] ?? '') as String,
      notes: map['notes'] != null ? Map<String, String>.from(map['notes'] as Map) : null,
      createdAt: map['createdAt'] != null || map['created_at'] != null
          ? DateTime.tryParse((map['createdAt'] ?? map['created_at']) as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory PaymentOrder.fromDjangoJson(Map<String, dynamic> json) => PaymentOrder.fromMap(json);
  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder.fromMap(json);
  Map<String, dynamic> toJson() => toDjangoJson();
}

/// Result returned from PhonePe payment launch and verification
class PaymentVerificationResult {
  final bool isSuccess;
  final String? transactionId;
  final String? paymentMethod;
  final String? errorMessage;
  final String? errorCode;

  const PaymentVerificationResult({
    required this.isSuccess,
    this.transactionId,
    this.paymentMethod,
    this.errorMessage,
    this.errorCode,
  });
}
