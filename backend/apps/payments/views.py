import hmac
import hashlib
import json
import logging
from django.conf import settings
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from .models import PaymentOrder
from .serializers import PaymentOrderSerializer
from apps.appointments.models import Appointment

logger = logging.getLogger(__name__)

class PaymentOrderViewSet(viewsets.ModelViewSet):
    """
    Payment Orders ViewSet.
    Handles creation and webhook verification of payment orders.
    """
    serializer_class = PaymentOrderSerializer
    lookup_field = 'order_id'
    
    # Apply rate limiting to this viewset, scoped as 'sensitive'
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sensitive'
    
    def get_queryset(self):
        qs = PaymentOrder.objects.all()
        # In real app, filter by current user's email/mobile
        return qs

    def get_permissions(self):
        if self.action in ['create', 'webhook']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    @action(detail=False, methods=['post'])
    def webhook(self, request):
        """
        Verify payment success via Razorpay Webhook.
        """
        signature = request.headers.get('X-Razorpay-Signature')
        if not signature:
            logger.warning("Webhook received without signature")
            return Response({"error": "Missing signature"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Verify HMAC-SHA256 signature
        body = request.body
        secret = settings.RAZORPAY_WEBHOOK_SECRET
        expected_signature = hmac.new(secret.encode('utf-8'), body, hashlib.sha256).hexdigest()
        
        if not hmac.compare_digest(expected_signature, signature):
            logger.warning("Invalid webhook signature")
            return Response({"error": "Invalid signature"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            event = request.data.get('event')
            
            # Strict format checking - no legacy support
            if not event:
                return Response({"error": "Invalid event payload"}, status=status.HTTP_400_BAD_REQUEST)

            if event not in ['payment.captured', 'order.paid']:
                return Response({"status": "ignored"})
                
            payload = request.data.get('payload', {})
            payment_entity = payload.get('payment', {}).get('entity', {})
            order_id = payment_entity.get('order_id')
            transaction_id = payment_entity.get('id')
            
            if not order_id or not transaction_id:
                return Response({"error": "order_id and transaction_id are required"}, status=status.HTTP_400_BAD_REQUEST)

            order = PaymentOrder.objects.get(order_id=order_id)
            
            if order.status == 'paid':
                logger.info(f"Webhook idempotency: Order {order_id} already paid.")
                return Response({"success": True, "message": "Already processed"})
            
            order.status = 'paid'
            order.gateway_order_id = transaction_id
            order.save()
            
            # Update corresponding Appointment
            try:
                appt = Appointment.objects.get(id=order.appointment_id)
                appt.payment_status = 'paid'
                appt.payment_transaction_id = transaction_id
                appt.booking_status = 'confirmed'
                appt.save()
            except Appointment.DoesNotExist:
                logger.error(f"Appointment {order.appointment_id} not found for order {order_id}")
                pass
                
            return Response({"success": True, "message": "Payment verified"})
                
        except PaymentOrder.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Webhook processing error: {e}")
            return Response({"error": "Internal error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
