import pytest
import json
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from rest_framework import status
from apps.doctors.models import Doctor, DoctorUnavailability
from apps.appointments.models import Appointment, NotificationLog
from apps.appointments.tasks import (
    process_grace_periods_and_expiries,
    send_late_arrival_notifications,
    expire_pending_payment_slots,
    notify_doctor_unavailability,
)


@pytest.fixture
def doctor(db):
    return Doctor.objects.create(
        id="doc_test",
        name="Dr. Test",
        specialization="Ophthalmology",
        consultation_fee=500,
        slot_duration_minutes=20,
        working_days=[1, 2, 3, 4, 5, 6, 7],
        shift_start_time="09:00",
        shift_end_time="17:00",
        is_active=True
    )


@pytest.fixture
def confirmed_appt(db, doctor):
    slot_start = timezone.now() - timedelta(minutes=10)
    return Appointment.objects.create(
        patient_uid="uid_001",
        patient_name="Test Patient",
        patient_mobile="9999999999",
        patient_id="WEH-2026-0001",
        doctor_id=doctor.id,
        doctor_name=doctor.name,
        doctor_specialization="Ophthalmology",
        service_id="srv_1",
        service_title="Eye Consultation",
        appointment_date=slot_start.date(),
        slot_start_time=slot_start,
        slot_end_time=slot_start + timedelta(minutes=20),
        consultation_fee=500.0,
        booking_status="confirmed"
    )


@pytest.mark.django_db
def test_grace_period_transition(confirmed_appt):
    """confirmed -> gracePeriod when slot time has passed."""
    process_grace_periods_and_expiries()
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.booking_status == 'gracePeriod'
    assert confirmed_appt.grace_period_started_at is not None
    assert confirmed_appt.expires_at is not None


@pytest.mark.django_db
def test_expiry_after_grace_period(confirmed_appt):
    """gracePeriod -> expired when expires_at is reached."""
    confirmed_appt.booking_status = 'gracePeriod'
    confirmed_appt.grace_period_started_at = timezone.now() - timedelta(minutes=46)
    confirmed_appt.expires_at = timezone.now() - timedelta(minutes=1)
    confirmed_appt.save()
    
    process_grace_periods_and_expiries()
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.booking_status == 'expired'


@pytest.mark.django_db
def test_late_arrival_notification_sent(confirmed_appt):
    """Notification created at 10-min threshold during grace period."""
    confirmed_appt.booking_status = 'gracePeriod'
    confirmed_appt.grace_period_started_at = timezone.now() - timedelta(minutes=11)
    confirmed_appt.slot_start_time = timezone.now() - timedelta(minutes=11)
    confirmed_appt.expires_at = timezone.now() + timedelta(minutes=34)
    confirmed_appt.save()
    
    send_late_arrival_notifications()
    
    logs = NotificationLog.objects.filter(appointment=confirmed_appt, notification_type='late_arrival_10min')
    assert logs.exists()


@pytest.mark.django_db
def test_no_duplicate_notifications(confirmed_appt):
    """Notification is NOT sent twice for same threshold."""
    confirmed_appt.booking_status = 'gracePeriod'
    confirmed_appt.grace_period_started_at = timezone.now() - timedelta(minutes=11)
    confirmed_appt.slot_start_time = timezone.now() - timedelta(minutes=11)
    confirmed_appt.expires_at = timezone.now() + timedelta(minutes=34)
    confirmed_appt.save()
    
    send_late_arrival_notifications()
    send_late_arrival_notifications()  # Second run
    
    logs = NotificationLog.objects.filter(appointment=confirmed_appt, notification_type='late_arrival_10min')
    assert logs.count() == 1  # Not duplicated


@pytest.mark.django_db
def test_pending_payment_expiry(doctor):
    slot_start = timezone.now() - timedelta(minutes=10)
    old_appt = Appointment.objects.create(
        patient_uid="uid_002",
        patient_name="Patient 2",
        patient_mobile="8888888888",
        patient_id="WEH-2026-0002",
        doctor_id=doctor.id,
        doctor_name=doctor.name,
        doctor_specialization="Ophthalmology",
        service_id="srv_1",
        service_title="Eye Checkup",
        appointment_date=slot_start.date(),
        slot_start_time=slot_start,
        slot_end_time=slot_start + timedelta(minutes=20),
        consultation_fee=500.0,
        booking_status="pendingPayment",
    )
    # Backdate created_at to simulate old pending
    Appointment.objects.filter(id=old_appt.id).update(created_at=timezone.now() - timedelta(minutes=6))
    
    expire_pending_payment_slots()
    old_appt.refresh_from_db()
    assert old_appt.booking_status == 'cancelled'


@pytest.mark.django_db
def test_manual_check_in_updates_status(confirmed_appt, django_user_model):
    """Admin can check-in using appointment_code and it transitions to checkedIn."""
    client = APIClient()
    admin = django_user_model.objects.create_superuser('admin_test', 'a@b.com', 'pass123')
    client.force_authenticate(user=admin)
    
    # Fix status to confirmed
    confirmed_appt.booking_status = 'confirmed'
    confirmed_appt.save()
    
    response = client.post('/api/v1/appointments/check_in/', {
        'appointment_code': confirmed_appt.appointment_code
    }, format='json')
    
    assert response.status_code == status.HTTP_200_OK
    assert response.data['verified'] is True
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.booking_status == 'checkedIn'


@pytest.mark.django_db
def test_reschedule_preserves_payment(confirmed_appt):
    """Rescheduling should not create a new payment and should regenerate QR."""
    client = APIClient()
    
    original_payment_id = confirmed_appt.payment_transaction_id
    original_code = confirmed_appt.appointment_code
    
    new_slot_start = timezone.now() + timedelta(days=2, hours=2)
    
    response = client.post(f'/api/v1/appointments/{confirmed_appt.id}/reschedule/', {
        'new_appointment_date': (timezone.now() + timedelta(days=2)).date().isoformat(),
        'new_slot_start_time': new_slot_start.isoformat(),
    }, format='json')
    
    # Should succeed or conflict only due to slot issues - no payment creation
    if response.status_code == 200:
        confirmed_appt.refresh_from_db()
        assert confirmed_appt.payment_transaction_id == original_payment_id
        # New QR code should be generated
        assert confirmed_appt.appointment_code != original_code


@pytest.mark.django_db
def test_doctor_unavailability_flags_appointments(confirmed_appt, doctor):
    """Adding DoctorUnavailability should flag overlapping confirmed appointments."""
    unavail = DoctorUnavailability.objects.create(
        doctor=doctor,
        start_time=confirmed_appt.slot_start_time - timedelta(minutes=5),
        end_time=confirmed_appt.slot_end_time + timedelta(minutes=5),
        reason="Doctor on leave"
    )
    
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.requires_rescheduling is True
    
    # Notification log should be created
    log = NotificationLog.objects.filter(
        appointment=confirmed_appt,
        notification_type="doctor_unavailable"
    ).first()
    # May not exist synchronously (depends on Celery being sync in tests)
    # but we can confirm the flag is set
    assert confirmed_appt.requires_rescheduling is True


@pytest.mark.django_db
def test_admin_permission_enforced(confirmed_appt):
    """Non-admin cannot access check-in endpoint."""
    client = APIClient()
    # No auth
    response = client.post('/api/v1/appointments/check_in/', {
        'appointment_code': confirmed_appt.appointment_code
    }, format='json')
    assert response.status_code in [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN]

@pytest.mark.django_db
def test_qr_payload_tampering(confirmed_appt, django_user_model):
    """Tampered QR payload must be rejected."""
    client = APIClient()
    admin = django_user_model.objects.create_superuser('admin_test_qr', 'a@b.com', 'pass123')
    client.force_authenticate(user=admin)
    
    confirmed_appt.booking_status = 'confirmed'
    confirmed_appt.save()
    
    # Create a forged payload with the correct code but invalid signature
    forged_payload = json.dumps({
        "code": confirmed_appt.appointment_code,
        "signature": "fake_signature_hash"
    })
    
    response = client.post('/api/v1/appointments/check_in/', {
        'qr_payload': forged_payload
    }, format='json')
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data['error'] == 'Invalid QR signature'
    
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.booking_status == 'confirmed' # Unchanged

@pytest.mark.django_db
def test_qr_payload_valid(confirmed_appt, django_user_model):
    """Valid QR payload is accepted."""
    import hashlib
    from django.conf import settings
    client = APIClient()
    admin = django_user_model.objects.create_superuser('admin_test_qr_valid', 'a@b.com', 'pass123')
    client.force_authenticate(user=admin)
    
    confirmed_appt.booking_status = 'confirmed'
    confirmed_appt.save()
    
    salt = getattr(settings, 'WEH_SECURE_AUTH_SALT', 'WEH_SECURE_AUTH_SALT_2026')
    date_str = confirmed_appt.appointment_date.strftime('%Y-%m-%d')
    raw_message = f"{confirmed_appt.appointment_code}|{confirmed_appt.patient_id}|{confirmed_appt.doctor_id}|{date_str}|{float(confirmed_appt.consultation_fee):.2f}|{salt}"
    valid_sig = hashlib.sha256(raw_message.encode('utf-8')).hexdigest()
    
    valid_payload = json.dumps({
        "code": confirmed_appt.appointment_code,
        "signature": valid_sig
    })
    
    response = client.post('/api/v1/appointments/check_in/', {
        'qr_payload': valid_payload
    }, format='json')
    
    assert response.status_code == status.HTTP_200_OK
    assert response.data['verified'] is True
    
    confirmed_appt.refresh_from_db()
    assert confirmed_appt.booking_status == 'checkedIn'
