from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import DoctorUnavailability
from apps.appointments.models import Appointment

@receiver(post_save, sender=DoctorUnavailability)
def flag_overlapping_appointments(sender, instance, created, **kwargs):
    pass
