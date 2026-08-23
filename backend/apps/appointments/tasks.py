from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from apps.appointments.models import Appointment, NotificationLog
from django.conf import settings
# Mocking Firebase per user agreement
# from firebase_admin import messaging

@shared_task
def process_grace_periods_and_expiries():
    now = timezone.now()
    
    # 1. confirmed -> grace_period
    due_for_grace = Appointment.objects.filter(
        booking_status='confirmed',
        slot_start_time__lte=now
    )
    
    grace_minutes = getattr(settings, 'GRACE_PERIOD_MINUTES', 45)
    
    for appt in due_for_grace:
        appt.booking_status = 'gracePeriod'
        appt.grace_period_started_at = now
        appt.expires_at = appt.slot_start_time + timedelta(minutes=grace_minutes)
        appt.save(update_fields=['booking_status', 'grace_period_started_at', 'expires_at'])
        
    # 2. grace_period -> expired
    due_for_expiry = Appointment.objects.filter(
        booking_status='gracePeriod',
        expires_at__lte=now
    )
    
    for appt in due_for_expiry:
        appt.booking_status = 'expired'
        appt.save(update_fields=['booking_status'])

@shared_task
def send_late_arrival_notifications():
    now = timezone.now()
    grace_appts = Appointment.objects.filter(booking_status='gracePeriod')
    
    for appt in grace_appts:
        if not appt.grace_period_started_at or not appt.expires_at:
            continue
            
        elapsed_minutes = (now - appt.slot_start_time).total_seconds() / 60.0
        
        thresholds = [10, 20, 30, 40]
        for t in thresholds:
            if elapsed_minutes >= t and elapsed_minutes < (t + 5): # 5 min window to account for cron jitter
                notif_type = f"late_arrival_{t}min"
                if not NotificationLog.objects.filter(appointment=appt, notification_type=notif_type).exists():
                    msg = f"You are running {t} minutes late for your {appt.slot_start_time.strftime('%I:%M %p')} appointment with Dr. {appt.doctor_name}."
                    
                    # Mock FCM send
                    # print(f"Sending FCM to {appt.patient_name}: {msg}")
                    
                    NotificationLog.objects.create(
                        appointment=appt,
                        notification_type=notif_type,
                        message=msg
                    )
                    break 

@shared_task
def expire_pending_payment_slots():
    now = timezone.now()
    expiry_threshold = now - timedelta(minutes=5)
    
    Appointment.objects.filter(
        booking_status='pendingPayment',
        created_at__lt=expiry_threshold
    ).update(
        booking_status='cancelled',
        cancellation_reason='Payment timeout (5 minutes expired)'
    )

@shared_task
def notify_doctor_unavailability(appt_id):
    try:
        appt = Appointment.objects.get(id=appt_id)
        msg = f"Your appointment with Dr. {appt.doctor_name} on {appt.appointment_date} needs to be rescheduled due to doctor unavailability."
        
        NotificationLog.objects.create(
            appointment=appt,
            notification_type="doctor_unavailable",
            message=msg
        )
    except Appointment.DoesNotExist:
        pass
