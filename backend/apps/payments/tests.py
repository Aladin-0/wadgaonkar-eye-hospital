import pytest
import hmac
import hashlib
import json
from unittest.mock import patch
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from rest_framework import status
from apps.payments.models import PaymentOrder
from apps.appointments.models import Appointment
from apps.payments.tasks import reconcile_pending_payments

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def payment_order(db):
    appt = Appointment.objects.create(
        patient_uid="uid123",
        patient_name="John Doe",
        doctor_id="doc1",
        doctor_name="Dr. Smith",
        service_id="srv1",
        service_title="Checkup",
        appointment_date=timezone.now().date(),
        slot_start_time=timezone.now() + timedelta(hours=1),
        slot_end_time=timezone.now() + timedelta(hours=1, minutes=30),
        consultation_fee=500.0,
        booking_status="pendingPayment",
    )
    order = PaymentOrder.objects.create(
        order_id="order_123",
        appointment_id=appt.id,
        amount=500.00,
        patient_name="John Doe",
        patient_mobile="1234567890",
        status="created"
    )
    return order

def generate_signature(body_bytes, secret):
    return hmac.new(secret.encode('utf-8'), body_bytes, hashlib.sha256).hexdigest()

@pytest.mark.django_db
def test_webhook_valid_signature(api_client, payment_order):
    payload = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "order_id": payment_order.order_id,
                    "id": "txn_abc123",
                    "status": "captured"
                }
            }
        }
    }
    body = json.dumps(payload).encode('utf-8')
    signature = generate_signature(body, settings.RAZORPAY_WEBHOOK_SECRET)
    
    response = api_client.post(
        '/api/v1/payments/webhook/',
        data=body,
        content_type='application/json',
        HTTP_X_RAZORPAY_SIGNATURE=signature
    )
    
    assert response.status_code == status.HTTP_200_OK
    payment_order.refresh_from_db()
    assert payment_order.status == 'paid'
    
    appt = Appointment.objects.get(id=payment_order.appointment_id)
    assert appt.payment_status == 'paid'
    assert appt.booking_status == 'confirmed'

@pytest.mark.django_db
def test_webhook_invalid_signature(api_client, payment_order):
    payload = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "order_id": payment_order.order_id,
                    "id": "txn_abc123"
                }
            }
        }
    }
    body = json.dumps(payload).encode('utf-8')
    # Use invalid secret
    signature = generate_signature(body, 'wrong_secret')
    
    response = api_client.post(
        '/api/v1/payments/webhook/',
        data=body,
        content_type='application/json',
        HTTP_X_RAZORPAY_SIGNATURE=signature
    )
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data['error'] == 'Invalid signature'
    payment_order.refresh_from_db()
    assert payment_order.status == 'created'

@pytest.mark.django_db
def test_webhook_idempotency(api_client, payment_order):
    payload = {
        "event": "payment.captured",
        "payload": {
            "payment": {
                "entity": {
                    "order_id": payment_order.order_id,
                    "id": "txn_abc123"
                }
            }
        }
    }
    body = json.dumps(payload).encode('utf-8')
    signature = generate_signature(body, settings.RAZORPAY_WEBHOOK_SECRET)
    
    # First request
    api_client.post(
        '/api/v1/payments/webhook/',
        data=body,
        content_type='application/json',
        HTTP_X_RAZORPAY_SIGNATURE=signature
    )
    
    # Second request
    response2 = api_client.post(
        '/api/v1/payments/webhook/',
        data=body,
        content_type='application/json',
        HTTP_X_RAZORPAY_SIGNATURE=signature
    )
    
    assert response2.status_code == status.HTTP_200_OK
    assert response2.data['message'] == 'Already processed'

@pytest.mark.django_db
@patch('apps.payments.tasks.requests.get')
def test_reconciliation_task(mock_get, payment_order):
    # Set the order's created_at to 20 minutes ago
    payment_order.created_at = timezone.now() - timedelta(minutes=20)
    payment_order.save()
    
    # Mock Razorpay API response
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {
        "items": [
            {
                "id": "txn_123",
                "status": "captured"
            }
        ]
    }
    
    reconcile_pending_payments()
    
    payment_order.refresh_from_db()
    assert payment_order.status == 'paid'
    assert payment_order.gateway_order_id == 'txn_123'
    
    appt = Appointment.objects.get(id=payment_order.appointment_id)
    assert appt.payment_status == 'paid'
    assert appt.booking_status == 'confirmed'

@pytest.mark.django_db
def test_webhook_missing_signature(api_client, payment_order):
    payload = {"event": "payment.captured"}
    response = api_client.post(
        '/api/v1/payments/webhook/',
        data=payload,
        format='json'
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data['error'] == 'Missing signature'
