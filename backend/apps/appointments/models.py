import hashlib
import json
import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone

class Appointment(models.Model):
    BOOKING_STATUS_CHOICES = [
        ('pendingPayment', 'Pending Payment'),
        ('confirmed', 'Confirmed'),
        ('gracePeriod', 'Grace Period (Running Late)'),
        ('checkedIn', 'Checked In'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
        ('noShow', 'No Show'),
        ('expired', 'Expired (No Show via automation)'),
        ('rescheduled', 'Rescheduled'),
    ]

    PAYMENT_STATUS_CHOICES = [
        ('pending', 'Payment Pending'),
        ('paid', 'Paid Online'),
        ('payAtHospitalDesk', 'Pay at Hospital Desk'),
        ('refunded', 'Refunded'),
        ('failed', 'Payment Failed'),
    ]

    id = models.CharField(max_length=128, primary_key=True, default=uuid.uuid4)
    appointment_code = models.CharField(max_length=64, unique=True, db_index=True)
    patient_uid = models.CharField(max_length=128, db_index=True)
    patient_name = models.CharField(max_length=255)
    patient_mobile = models.CharField(max_length=20)
    patient_age = models.PositiveIntegerField(default=0)
    patient_gender = models.CharField(max_length=20, blank=True, null=True)
    patient_id = models.CharField(max_length=64, db_index=True)
    
    doctor_id = models.CharField(max_length=64, db_index=True)
    doctor_name = models.CharField(max_length=255)
    doctor_specialization = models.CharField(max_length=255)
    doctor_qualification = models.CharField(max_length=255, blank=True, null=True)
    
    service_id = models.CharField(max_length=64)
    service_title = models.CharField(max_length=255)
    
    appointment_date = models.DateField(db_index=True)
    slot_start_time = models.DateTimeField()
    slot_end_time = models.DateTimeField()
    
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    booking_status = models.CharField(max_length=50, choices=BOOKING_STATUS_CHOICES, default='confirmed')
    payment_status = models.CharField(max_length=50, choices=PAYMENT_STATUS_CHOICES, default='pending')
    payment_method = models.CharField(max_length=100, blank=True, null=True)
    payment_transaction_id = models.CharField(max_length=128, blank=True, null=True)
    
    qr_payload = models.TextField(blank=True)
    qr_signature = models.CharField(max_length=255, blank=True, null=True)
    cancellation_reason = models.TextField(blank=True, null=True)
    
    # Phase 4 automated lifecycle timestamps
    grace_period_started_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField(blank=True, null=True)
    checked_in_at = models.DateTimeField(blank=True, null=True)
    requires_rescheduling = models.BooleanField(default=False, help_text="Flagged when doctor becomes unavailable")
    
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-appointment_date', '-slot_start_time']
        constraints = [
            models.UniqueConstraint(
                fields=['doctor_id', 'appointment_date', 'slot_start_time'],
                condition=models.Q(booking_status__in=['confirmed', 'pendingPayment', 'completed']),
                name='unique_active_appointment_slot'
            )
        ]

    def save(self, *args, **kwargs):
        if not self.appointment_code:
            date_str = self.appointment_date.strftime('%Y%m%d')
            clean_appt_id = str(self.id).replace('-', '')
            suffix = clean_appt_id[-4:].upper() if len(clean_appt_id) >= 4 else '0001'
            self.appointment_code = f"WEH-{date_str}-OPD-{suffix}"
            
        if not self.qr_signature:
            self._generate_qr()
            
        super().save(*args, **kwargs)

    def _generate_qr(self):
        date_str = self.appointment_date.strftime('%Y-%m-%d')
        salt = getattr(settings, 'WEH_SECURE_AUTH_SALT', 'WEH_SECURE_AUTH_SALT_2026')
        raw_message = f"{self.appointment_code}|{self.patient_id}|{self.doctor_id}|{date_str}|{float(self.consultation_fee):.2f}|{salt}"
        self.qr_signature = hashlib.sha256(raw_message.encode('utf-8')).hexdigest()
        
        qr_map = {
            'hospital': 'Wadgaonkar Eye Hospital',
            'code': self.appointment_code,
            'patient_id': self.patient_id,
            'patient_name': self.patient_name,
            'doctor': self.doctor_name,
            'doctor_id': self.doctor_id,
            'service': self.service_title,
            'date': date_str,
            'time': f"{self.slot_start_time.strftime('%I:%M %p')} - {self.slot_end_time.strftime('%I:%M %p')}",
            'fee': float(self.consultation_fee),
            'payment_status': self.payment_status,
            'status': self.booking_status,
            'signature': self.qr_signature,
            'issued_at': timezone.now().isoformat(),
        }
        self.qr_payload = json.dumps(qr_map)

    def __str__(self):
        return f"{self.appointment_code} - {self.patient_name} with {self.doctor_name}"

class NotificationLog(models.Model):
    appointment = models.ForeignKey(Appointment, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=50, help_text="e.g. late_arrival_10min, doctor_unavailable")
    sent_at = models.DateTimeField(default=timezone.now)
    message = models.TextField(blank=True)

    class Meta:
        ordering = ['-sent_at']

    def __str__(self):
        return f"{self.notification_type} for {self.appointment.appointment_code} at {self.sent_at}"

