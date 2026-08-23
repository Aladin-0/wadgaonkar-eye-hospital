import 'package:weh_shared/weh_shared.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../core/errors/app_exception.dart';

abstract class IPaymentGatewayService {
  Future<PaymentOrder> createOrder({
    required double amount,
    required String appointmentId,
    required String patientName,
    required String patientMobile,
    required String patientEmail,
    Map<String, String>? notes,
  });

  Future<PaymentVerificationResult> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}

/// Payment Gateway Service implementing order preparation and signature verification.
/// Designed for standard Razorpay / Payment Gateway webhook verification via backend.
class PaymentGatewayService implements IPaymentGatewayService {
  @override
  Future<PaymentOrder> createOrder({
    required double amount,
    required String appointmentId,
    required String patientName,
    required String patientMobile,
    required String patientEmail,
    Map<String, String>? notes,
  }) async {
    try {
      final now = DateTime.now();
      final orderId = 'order_weh_${now.millisecondsSinceEpoch}';

      developer.log(
        'Creating payment order for appointment $appointmentId (Amount: ₹$amount)',
        name: 'PaymentGatewayService',
      );

      // In production with Django REST backend, this calls `POST /api/v1/payments/create-order/`
      // which interacts securely with Razorpay Orders API using server secrets.
      return PaymentOrder(
        orderId: orderId,
        appointmentId: appointmentId,
        amount: amount,
        currency: 'INR',
        gatewayName: 'Razorpay',
        gatewayOrderId: 'rzp_order_${now.millisecondsSinceEpoch}',
        status: 'created',
        patientName: patientName,
        patientMobile: patientMobile,
        patientEmail: patientEmail,
        notes: notes,
        createdAt: now,
      );
    } catch (e) {
      developer.log('Order creation failure: $e', name: 'PaymentGatewayService', error: e);
      throw ProfileException('Failed to initialize payment gateway order.');
    }
  }

  @override
  Future<PaymentVerificationResult> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      // In production with Django REST backend, this calls `POST /api/v1/payments/verify/`
      // which verifies the HMAC-SHA256 signature against Razorpay webhook secrets.
      developer.log(
        'Verifying payment: Order=$orderId, Payment=$paymentId',
        name: 'PaymentGatewayService',
      );

      if (signature.isEmpty || paymentId.isEmpty) {
        return const PaymentVerificationResult(
          isSuccess: false,
          errorMessage: 'Invalid payment signature or missing transaction token.',
          errorCode: 'INVALID_SIGNATURE',
        );
      }

      // In production, you would perform an actual HTTP request to your Django backend here.
      // E.g. final response = await http.post('/api/v1/payments/verify/', data: {...});
      // Removing the fake delay that was here for mock purposes.
      if (kDebugMode) {
        return PaymentVerificationResult(
          isSuccess: true,
          transactionId: paymentId.isNotEmpty ? paymentId : 'txn_weh_${DateTime.now().millisecondsSinceEpoch}',
          paymentMethod: 'UPI / Razorpay Gateway',
        );
      } else {
        // Production must rely on real verification
        return const PaymentVerificationResult(
          isSuccess: false,
          errorMessage: 'Server signature verification required in production environment.',
          errorCode: 'BACKEND_VERIFICATION_REQUIRED',
        );
      }
    } catch (e) {
      developer.log('Payment verification error: $e', name: 'PaymentGatewayService', error: e);
      return PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'Payment verification failed: $e',
        errorCode: 'VERIFICATION_EXCEPTION',
      );
    }
  }
}
