from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from apps.appointments.models import Appointment

class Command(BaseCommand):
    help = 'Expires pendingPayment appointments older than 5 minutes'

    def handle(self, *args, **kwargs):
        expiry_threshold = timezone.now() - timedelta(minutes=5)
        
        # Find all pending appointments older than 5 minutes
        stale_appts = Appointment.objects.filter(
            booking_status='pendingPayment',
            created_at__lt=expiry_threshold
        )
        
        count = stale_appts.count()
        if count > 0:
            stale_appts.update(
                booking_status='cancelled', 
                cancellation_reason='Payment timeout (5 minutes expired)'
            )
            self.stdout.write(self.style.SUCCESS(f'Successfully expired {count} pending appointment(s).'))
        else:
            self.stdout.write(self.style.SUCCESS('No stale appointments found.'))
