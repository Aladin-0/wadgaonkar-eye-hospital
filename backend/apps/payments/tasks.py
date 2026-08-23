from celery import shared_task
from django.utils import timezone
from datetime import timedelta
import requests
import logging
from django.conf import settings
from .models import PaymentOrder
from apps.appointments.models import Appointment

logger = logging.getLogger(__name__)

@shared_task
def reconcile_pending_payments():
    """
    Finds PaymentOrders stuck in 'created' state for more than 15 minutes,
    and queries Razorpay API directly to see if they were actually paid
    (in case the webhook failed or was delayed).
    """
    threshold_time = timezone.now() - timedelta(minutes=15)
    # Get created orders older than 15 minutes but younger than 1 hour (to avoid scanning forever)
    orders = PaymentOrder.objects.filter(
        status='created', 
        created_at__lte=threshold_time,
        created_at__gte=timezone.now() - timedelta(hours=1)
    )
    
    for order in orders:
        try:
            response = requests.get(
                f"https://api.razorpay.com/v1/orders/{order.order_id}/payments",
                auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET),
                timeout=10
            )
            
            if response.status_code == 200:
                data = response.json()
                items = data.get('items', [])
                
                # Check if any payment for this order is captured/paid
                is_paid = any(item.get('status') == 'captured' for item in items)
                
                if is_paid:
                    # Find the captured payment
                    captured_payment = next((item for item in items if item.get('status') == 'captured'), None)
                    transaction_id = captured_payment.get('id') if captured_payment else None
                    
                    logger.info(f"Reconciliation successful for order {order.order_id}. Marking as paid.")
                    order.status = 'paid'
                    order.gateway_order_id = transaction_id
                    order.save()
                    
                    try:
                        appt = Appointment.objects.get(id=order.appointment_id)
                        appt.payment_status = 'paid'
                        appt.payment_transaction_id = transaction_id
                        appt.booking_status = 'confirmed'
                        appt.save()
                    except Appointment.DoesNotExist:
                        pass
                else:
                    # Not paid
                    pass
            else:
                logger.error(f"Razorpay API error for order {order.order_id}: {response.text}")
                
        except Exception as e:
            logger.error(f"Error reconciling order {order.order_id}: {e}")
