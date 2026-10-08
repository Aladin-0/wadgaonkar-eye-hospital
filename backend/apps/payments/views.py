import hmac
import hashlib
import uuid
import logging

import requests as http_requests
from django.conf import settings
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from .models import PaymentOrder
from .serializers import PaymentOrderSerializer
from apps.appointments.models import Appointment

logger = logging.getLogger(__name__)


def _verify_firebase_token(request):
    auth_header = request.headers.get('Authorization', '')
    if not auth_header:
        return None, 'No Authorization header found'
    if not auth_header.startswith('Bearer '):
        return None, 'Invalid Authorization header format'
    id_token = auth_header[7:]
    if not id_token:
        return None, 'Empty ID token'
    try:
        import firebase_admin.auth as fb_auth
        decoded = fb_auth.verify_id_token(id_token)
        return decoded.get('uid'), None
    except Exception as e:
        return None, str(e)


class PaymentOrderViewSet(viewsets.ModelViewSet):
    serializer_class = PaymentOrderSerializer
    lookup_field = 'order_id'
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sensitive'

    def get_queryset(self):
        return PaymentOrder.objects.all()

    def get_permissions(self):
        action = getattr(self, 'action', None)
        if action in ['initiate', 'verify', 'metadata']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def get_authenticators(self):
        if hasattr(self, 'request'):
            path = self.request.path
            if '/initiate' in path or '/verify' in path:
                return []
        return super().get_authenticators()

    @action(detail=False, methods=['post'], url_path='initiate')
    def initiate(self, request):
        uid, err = _verify_firebase_token(request)
        if not uid:
            return Response(
                {'error': f'Auth Failed: {err}'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        appointment_id = request.data.get('appointment_id')
        patient_mobile = request.data.get('patient_mobile', '')
        patient_email = request.data.get('patient_email', '')
        patient_name = request.data.get('patient_name', '')

        if not appointment_id:
            return Response(
                {'error': 'Invalid request parameters.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            appointment = Appointment.objects.get(id=appointment_id)
        except Appointment.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if appointment.patient_uid != uid:
            logger.warning(
                'Ownership violation: uid=%s attempted appointment=%s owned by uid=%s',
                uid, appointment_id, appointment.patient_uid
            )
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if appointment.payment_status == 'paid':
            return Response({'error': 'Already paid.'}, status=status.HTTP_409_CONFLICT)

        existing = PaymentOrder.objects.filter(
            appointment_id=appointment_id,
            status='created'
        ).order_by('-created_at').first()

        if existing:
            return Response({
                'order_id': str(existing.order_id),
                'merchant_transaction_id': existing.merchant_transaction_id,
                'razorpay_order_id': existing.gateway_order_id,
                'amount': float(existing.amount),
                'currency': 'INR',
                'key': settings.RAZORPAY_KEY_ID,
            }, status=status.HTTP_200_OK)

        authoritative_amount = float(appointment.consultation_fee)
        if authoritative_amount <= 0:
            return Response({'error': 'Invalid fee configuration.'}, status=status.HTTP_400_BAD_REQUEST)

        amount_paise = int(authoritative_amount * 100)
        merchant_txn_id = f"WEH-{uuid.uuid4().hex[:28].upper()}"

        try:
            auth = (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
            payload = {
                'amount': amount_paise,
                'currency': 'INR',
                'receipt': merchant_txn_id,
                'payment_capture': 1,
            }
            resp = http_requests.post(
                'https://api.razorpay.com/v1/orders',
                json=payload,
                auth=auth,
                timeout=15,
            )
            resp.raise_for_status()
            razorpay_order = resp.json()
        except Exception as exc:
            logger.error('Gateway call failed: %s', exc)
            return Response(
                {'error': 'Payment gateway unavailable. Please try again.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        razorpay_order_id = razorpay_order.get('id')
        if not razorpay_order_id:
            logger.error('Gateway returned no order id: %s', razorpay_order)
            return Response({'error': 'Gateway error.'}, status=status.HTTP_502_BAD_GATEWAY)

        order = PaymentOrder.objects.create(
            order_id=uuid.uuid4(),
            appointment_id=appointment_id,
            amount=authoritative_amount,
            currency='INR',
            gateway_name='Razorpay',
            merchant_transaction_id=merchant_txn_id,
            gateway_order_id=razorpay_order_id,
            status='created',
            patient_name=patient_name,
            patient_mobile=patient_mobile,
            patient_email=patient_email,
        )

        logger.info('Order created: %s rz=%s amt=%.2f', order.order_id, razorpay_order_id, authoritative_amount)

        return Response({
            'order_id': str(order.order_id),
            'merchant_transaction_id': merchant_txn_id,
            'razorpay_order_id': razorpay_order_id,
            'amount': authoritative_amount,
            'currency': 'INR',
            'key': settings.RAZORPAY_KEY_ID,
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'], url_path='verify')
    def verify(self, request):
        uid, err = _verify_firebase_token(request)
        if not uid:
            return Response({'error': f'Auth Failed: {err}'}, status=status.HTTP_401_UNAUTHORIZED)

        razorpay_payment_id = request.data.get('razorpay_payment_id', '').strip()
        razorpay_order_id = request.data.get('razorpay_order_id', '').strip()
        razorpay_signature = request.data.get('razorpay_signature', '').strip()
        merchant_txn_id = request.data.get('merchant_transaction_id', '').strip()

        if not all([razorpay_payment_id, razorpay_order_id, razorpay_signature, merchant_txn_id]):
            return Response({'error': 'Invalid request.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = PaymentOrder.objects.get(merchant_transaction_id=merchant_txn_id)
        except PaymentOrder.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            appointment = Appointment.objects.get(id=order.appointment_id)
        except Appointment.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if appointment.patient_uid != uid:
            logger.warning(
                'Verify ownership violation: uid=%s merchant_txn=%s', uid, merchant_txn_id
            )
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if order.status == 'paid':
            return Response({'success': True, 'message': 'Confirmed.'})

        expected = hmac.new(
            settings.RAZORPAY_KEY_SECRET.encode('utf-8'),
            f"{razorpay_order_id}|{razorpay_payment_id}".encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(expected, razorpay_signature):
            order.status = 'failed'
            order.save(update_fields=['status', 'updated_at'])
            logger.warning('Signature mismatch for merchant_txn=%s', merchant_txn_id)
            return Response(
                {'success': False, 'message': 'Verification failed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.status = 'paid'
        order.gateway_order_id = razorpay_payment_id
        order.save(update_fields=['status', 'gateway_order_id', 'updated_at'])

        appointment.payment_status = 'paid'
        appointment.payment_transaction_id = razorpay_payment_id
        appointment.booking_status = 'confirmed'
        appointment.save(update_fields=['payment_status', 'payment_transaction_id', 'booking_status', 'updated_at'])

        logger.info('Appointment %s confirmed. payment=%s', appointment.id, razorpay_payment_id)

        return Response({'success': True, 'message': 'Confirmed.'})
