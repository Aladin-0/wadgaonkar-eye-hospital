from rest_framework import viewsets, permissions
from .models import Doctor, DoctorUnavailability
from .serializers import DoctorSerializer, DoctorUnavailabilitySerializer

class DoctorViewSet(viewsets.ModelViewSet):
    """
    Hospital Doctor ViewSet.
    Public list and retrieve for patients, authenticated admin for CRUD.
    """
    serializer_class = DoctorSerializer
    lookup_field = 'id'

    def get_queryset(self):
        qs = Doctor.objects.all()
        # Default public users only see active doctors
        if not (self.request.user and self.request.user.is_staff):
            qs = qs.filter(is_active=True)
        return qs

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

class DoctorUnavailabilityViewSet(viewsets.ModelViewSet):
    """
    Manage Doctor Unavailability.
    """
    serializer_class = DoctorUnavailabilitySerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        qs = DoctorUnavailability.objects.all()
        doctor_id = self.request.query_params.get('doctor_id')
        if doctor_id:
            qs = qs.filter(doctor_id=doctor_id)
        return qs

    def perform_create(self, serializer):
        instance = serializer.save()
        
        # Check for overlapping appointments and mark them as needsReschedule
        from apps.appointments.models import Appointment, NotificationLog
        
        overlapping_appts = Appointment.objects.filter(
            doctor_id=instance.doctor.id,
            booking_status__in=['confirmed', 'pendingPayment'],
            slot_start_time__lt=instance.end_time,
            slot_end_time__gt=instance.start_time
        )
        
        for appt in overlapping_appts:
            appt.booking_status = 'needsReschedule'
            appt.save(update_fields=['booking_status'])
            
            NotificationLog.objects.create(
                appointment=appt,
                notification_type='doctor_unavailable',
                message='Doctor emergency. Please reschedule.'
            )
            
            # Send Push Notification to the Patient
            try:
                from apps.authentication.models import PatientProfile
                profile = PatientProfile.objects.filter(uid=appt.patient_uid).first()
                if profile and profile.fcm_token:
                    import firebase_admin
                    from firebase_admin import messaging
                    
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title="Action Required: Appointment Cancelled",
                            body=f"Your appointment with {appt.doctor_name} was cancelled due to a doctor emergency. Tap to reschedule for free."
                        ),
                        data={
                            'type': 'appointment_cancellation',
                            'appointment_id': str(appt.id),
                            'patient_uid': str(appt.patient_uid),
                        },
                        android=messaging.AndroidConfig(
                            priority='high',
                            notification=messaging.AndroidNotification(
                                click_action='FLUTTER_NOTIFICATION_CLICK',
                            ),
                        ),
                        token=profile.fcm_token,
                    )
                    messaging.send(message)
            except Exception as e:
                import logging
                logging.error(f"Failed to send push notification: {e}")
