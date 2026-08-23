import uuid
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone

class PatientProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='patient_profile')
    uid = models.CharField(max_length=128, unique=True, db_index=True, help_text="Firebase UID or Client UUID")
    full_name = models.CharField(max_length=255)
    mobile_number = models.CharField(max_length=20, db_index=True)
    email = models.EmailField(blank=True, null=True)
    age = models.PositiveIntegerField(default=0)
    gender = models.CharField(max_length=20, blank=True, null=True)
    patient_id = models.CharField(max_length=64, unique=True, db_index=True, help_text="Hospital Registered ID e.g. WEH-2026-0042")
    city = models.CharField(max_length=100, default='Ahmednagar')
    blood_group = models.CharField(max_length=10, blank=True, null=True)
    photo_url = models.URLField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    pincode = models.CharField(max_length=20, blank=True, null=True)
    emergency_contact = models.CharField(max_length=50, blank=True, null=True)
    medical_notes = models.TextField(blank=True, null=True)
    is_profile_complete = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Patient Case Record'
        verbose_name_plural = 'Patient Case Records'
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.patient_id:
            # Auto-generate clinical patient ID e.g. WEH-2026-XXXX
            year = timezone.now().year
            suffix = uuid.uuid4().hex[:4].upper()
            self.patient_id = f"WEH-{year}-{suffix}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.full_name} ({self.patient_id}) - {self.mobile_number}"

class AuditLog(models.Model):
    admin_user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='audit_logs')
    action = models.CharField(max_length=255)
    details = models.TextField(blank=True, null=True)
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    timestamp = models.DateTimeField(default=timezone.now)

    class Meta:
        verbose_name = 'Audit Log'
        verbose_name_plural = 'Audit Logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f"[{self.timestamp}] {self.admin_user} - {self.action}"
