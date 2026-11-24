import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:weh_shared/weh_shared.dart';
import '../../core/errors/app_exception.dart';

const String _kBase = "https://techverseservices.in/hospital-api/api/v1";

abstract class IPaymentGatewayService {
  Future<RazorpayPaymentSession> initiateOrder({
    required double amount,
    required String appointmentId,
    required String patientName,
    required String patientMobile,
    required String patientEmail,
  });

  Future<PaymentVerificationResult> launchAndVerify({
    required RazorpayPaymentSession session,
  });
}

class RazorpayPaymentSession {
  final String orderId;
  final String merchantTransactionId;
  final String razorpayOrderId;
  final double amount;
  final String key;
  final String patientMobile;
  final String patientEmail;

  const RazorpayPaymentSession({
    required this.orderId,
    required this.merchantTransactionId,
    required this.razorpayOrderId,
    required this.amount,
    required this.key,
    required this.patientMobile,
    required this.patientEmail,
  });
}

class PaymentGatewayService implements IPaymentGatewayService {
  late final Dio _dio;

  PaymentGatewayService() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  Future<String?> _idToken() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RazorpayPaymentSession> initiateOrder({
    required double amount,
    required String appointmentId,
    required String patientName,
    required String patientMobile,
    required String patientEmail,
  }) async {
    final token = await _idToken();
    if (token == null) throw ProfileException('Session expired. Please sign in again.');

    try {
      final response = await _dio.post(
        '/payments/initiate/',
        data: {
          'appointment_id': appointmentId,
          'patient_name': patientName,
          'patient_mobile': patientMobile,
          'patient_email': patientEmail,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;

      return RazorpayPaymentSession(
        orderId: data['order_id'] as String,
        merchantTransactionId: data['merchant_transaction_id'] as String,
        razorpayOrderId: data['razorpay_order_id'] as String,
        amount: (data['amount'] as num).toDouble(),
        key: data['key'] as String,
        patientMobile: patientMobile,
        patientEmail: patientEmail,
      );
    } on DioException catch (e) {
      final msg = _msg(e) ?? 'Payment initiation failed. Please try again.';
      throw ProfileException(msg);
    }
  }

  @override
  Future<PaymentVerificationResult> launchAndVerify({
    required RazorpayPaymentSession session,
  }) async {
    final completer = Completer<PaymentVerificationResult>();
    final razorpay = Razorpay();

    void onSuccess(PaymentSuccessResponse r) async {
      try {
        final result = await _verify(
          paymentId: r.paymentId ?? '',
          orderId: r.orderId ?? '',
          signature: r.signature ?? '',
          merchantTxnId: session.merchantTransactionId,
        );
        completer.complete(result);
      } catch (e) {
        completer.complete(PaymentVerificationResult(
          isSuccess: false,
          errorMessage: 'Verification failed. Contact support.',
          errorCode: 'VERIFY_ERR',
        ));
      } finally {
        razorpay.clear();
      }
    }

    void onError(PaymentFailureResponse r) {
      completer.complete(PaymentVerificationResult(
        isSuccess: false,
        errorMessage: _friendlyError(r.code, r.message),
        errorCode: 'PAYMENT_FAILED',
      ));
      razorpay.clear();
    }

    void onWallet(ExternalWalletResponse r) {
      completer.complete(PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'External wallets are not supported.',
        errorCode: 'WALLET',
      ));
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWallet);

    final options = {
      'key': session.key,
      'amount': (session.amount * 100).toInt(),
      'order_id': session.razorpayOrderId,
      'name': 'Wadgaonkar Eye Hospital',
      'description': 'OPD Consultation',
      'prefill': {
        'contact': session.patientMobile,
        'email': session.patientEmail,
      },
      'theme': {'color': '#0B2447'},
      'modal': {'backdropclose': false, 'confirm_close': true},
      'retry': {'enabled': true, 'max_count': 3},
      'send_sms_hash': true,
    };

    try {
      razorpay.open(options);
    } catch (_) {
      return PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'Could not open payment gateway.',
        errorCode: 'SDK_ERR',
      );
    }

    return completer.future;
  }

  Future<PaymentVerificationResult> _verify({
    required String paymentId,
    required String orderId,
    required String signature,
    required String merchantTxnId,
  }) async {
    final token = await _idToken();
    if (token == null) {
      return PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'Session expired during verification.',
        errorCode: 'AUTH_ERR',
      );
    }

    try {
      final response = await _dio.post(
        '/payments/verify/',
        data: {
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
          'merchant_transaction_id': merchantTxnId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaymentVerificationResult(
          isSuccess: true,
          transactionId: paymentId,
          paymentMethod: 'Razorpay',
        );
      }
      return PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'Payment could not be verified.',
        errorCode: 'VERIFY_FAILED',
      );
    } on DioException catch (e) {
      developer.log('Verify network error', name: 'PGS', error: e);
      return PaymentVerificationResult(
        isSuccess: false,
        errorMessage: 'Could not verify payment. Please contact hospital support with your UPI/card reference.',
        errorCode: 'NET_ERR',
        transactionId: merchantTxnId,
      );
    }
  }

  String _friendlyError(int? code, String? message) {
    switch (code) {
      case Razorpay.PAYMENT_CANCELLED:
        return 'Payment was cancelled.';
      case Razorpay.NETWORK_ERROR:
        return 'No internet connection during payment. Please try again.';
      case Razorpay.INVALID_OPTIONS:
        return 'Payment configuration error. Please contact support.';
      default:
        final raw = message?.toLowerCase() ?? '';
        if (raw.contains('bank')) return 'Bank declined the transaction. Please try another payment method.';
        if (raw.contains('upi')) return 'UPI payment failed. Please try again or use another method.';
        if (raw.contains('insufficient')) return 'Insufficient balance. Please try another payment method.';
        return 'Payment unsuccessful. Please try again.';
    }
  }

  String? _msg(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['error'] as String?;
    } catch (_) {}
    return null;
  }
}
