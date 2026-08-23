from django.db import models
from django.utils import timezone

class Doctor(models.Model):
    id = models.CharField(max_length=64, primary_key=True, help_text="Unique doctor identifier e.g. doc_anand")
    name = models.CharField(max_length=255)
    qualification = models.CharField(max_length=255, default='MBBS, MS Ophthalmology')
    specialization = models.CharField(max_length=255)
    experience_years = models.PositiveIntegerField(default=0)
    profile_image_url = models.URLField(blank=True, null=True)
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, default=600.00)
    slot_duration_minutes = models.PositiveIntegerField(default=20)
    working_days = models.JSONField(default=list, help_text="List of day integers 1=Monday .. 7=Sunday")
    shift_start_time = models.CharField(max_length=8, default='09:00', help_text="HH:MM format")
    shift_end_time = models.CharField(max_length=8, default='19:30', help_text="HH:MM format")
    break_start_time = models.CharField(max_length=8, default='13:30', blank=True, null=True)
    break_end_time = models.CharField(max_length=8, default='16:00', blank=True, null=True)
    is_active = models.BooleanField(default=True, db_index=True)
    supported_service_ids = models.JSONField(default=list, blank=True, help_text="List of service IDs e.g. ['srv_cataract', 'srv_lasik']")
    bio = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Doctor Consultant'
        verbose_name_plural = 'Doctor Consultants'
        ordering = ['name']

    def __str__(self):
        return f"{self.name} - {self.specialization}"


class DoctorUnavailability(models.Model):
    doctor = models.ForeignKey(Doctor, on_delete=models.CASCADE, related_name='unavailability_periods')
    start_time = models.DateTimeField(help_text="Start of unavailability period")
    end_time = models.DateTimeField(help_text="End of unavailability period")
    reason = models.CharField(max_length=255, blank=True, null=True, help_text="e.g. Leave, Sick, Emergency")
    
    class Meta:
        verbose_name = 'Doctor Unavailability'
        verbose_name_plural = 'Doctor Unavailabilities'
        ordering = ['start_time']

    def __str__(self):
        return f"{self.doctor.name} unavailable from {self.start_time.strftime('%Y-%m-%d %H:%M')} to {self.end_time.strftime('%Y-%m-%d %H:%M')}"

