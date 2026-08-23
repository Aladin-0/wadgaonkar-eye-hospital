from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import DoctorUnavailability
from apps.appointments.models import Appointment

@receiver(post_save, sender=DoctorUnavailability)
def flag_overlapping_appointments(sender, instance, created, **kwargs):
    if created:
        affected_appts = Appointment.objects.filter(
            doctor_id=instance.doctor.id,
            booking_status__in=['confirmed', 'gracePeriod'],
            slot_start_time__lt=instance.end_time,
            slot_end_time__gt=instance.start_time
        )
        
        if affected_appts.exists():
            affected_appts.update(requires_rescheduling=True)
            from apps.appointments.tasks import notify_doctor_unavailability
            for appt in affected_appts:
                notify_doctor_unavailability.delay(appt.id)
