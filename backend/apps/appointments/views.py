import json
import hashlib
from datetime import datetime, timedelta
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from django.utils import timezone
from django.conf import settings
from django.db import transaction, IntegrityError
from .models import Appointment
from .serializers import AppointmentSerializer
from apps.doctors.models import Doctor, DoctorUnavailability

class AppointmentViewSet(viewsets.ModelViewSet):
    """
    Appointments ViewSet.
    Patients can see their own appointments. Admins see all.
    """
    serializer_class = AppointmentSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'sensitive'
    lookup_field = 'id'

    def get_queryset(self):
        qs = Appointment.objects.all()
        if not (self.request.user and self.request.user.is_staff):
            uid = self.request.query_params.get('uid')
            if uid:
                qs = qs.filter(patient_uid=uid)
            else:
                qs = Appointment.objects.none()
        return qs

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'create', 'partial_update', 'slots', 'check_in']:
            # Adjust permissions as per real auth later. Admin actions like check_in should be IsAdminUser eventually.
            # But based on Fix 5 requirements, we'll keep patient-facing ones AllowAny and admin ones Admin.
            if self.action == 'check_in':
                return [permissions.IsAdminUser()]
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def create(self, request, *args, **kwargs):
        """
        Creates an appointment securely, preventing double-booking using DB locking and constraints.
        Sets initial status to 'pendingPayment'.
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        
        doctor_id = data.get('doctor_id')
        appt_date = data.get('appointment_date')
        slot_time = data.get('slot_start_time')

        try:
            with transaction.atomic():
                # 1. Lock the Doctor row to serialize concurrent booking requests for this doctor.
                try:
                    doctor = Doctor.objects.select_for_update().get(id=doctor_id)
                except Doctor.DoesNotExist:
                    return Response({"error": "Doctor not found"}, status=status.HTTP_404_NOT_FOUND)
                
                # 2. Check if a conflicting active appointment exists
                conflict = Appointment.objects.filter(
                    doctor_id=doctor_id,
                    appointment_date=appt_date,
                    slot_start_time=slot_time,
                    booking_status__in=['confirmed', 'pendingPayment', 'completed']
                ).exists()
                
                if conflict:
                    return Response({"error": "Slot unavailable", "detail": "This slot has already been booked."}, status=status.HTTP_409_CONFLICT)
                
                # 3. Create the appointment. The UniqueConstraint in models.py acts as a secondary safety net.
                # Force status to pendingPayment to hold the slot.
                data['booking_status'] = 'pendingPayment'
                data['payment_status'] = 'pending'
                
                self.perform_create(serializer)
                headers = self.get_success_headers(serializer.data)
                return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
                
        except IntegrityError:
            # Caught the DB constraint violation if something slipped through
            return Response({"error": "Slot unavailable", "detail": "This slot has just been booked by someone else."}, status=status.HTTP_409_CONFLICT)

    @action(detail=False, methods=['get'])
    def slots(self, request):
        """
        Dynamically generate time slots for a given doctor and date.
        Respects DoctorUnavailability (to be implemented).
        """
        doctor_id = request.query_params.get('doctor_id')
        date_str = request.query_params.get('date')
        
        if not doctor_id or not date_str:
            return Response({"error": "doctor_id and date are required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
            doctor = Doctor.objects.get(id=doctor_id)
        except (ValueError, Doctor.DoesNotExist):
            return Response({"error": "Invalid date or doctor_id"}, status=status.HTTP_400_BAD_REQUEST)

        # Check if doctor works on this day of week (1=Mon, 7=Sun)
        weekday = date_obj.isoweekday()
        if weekday not in doctor.working_days:
            return Response({"slots": []})

        slots = []
        try:
            start_time = datetime.strptime(f"{date_str} {doctor.shift_start_time}", '%Y-%m-%d %H:%M')
            end_time = datetime.strptime(f"{date_str} {doctor.shift_end_time}", '%Y-%m-%d %H:%M')
            break_start = datetime.strptime(f"{date_str} {doctor.break_start_time}", '%Y-%m-%d %H:%M') if doctor.break_start_time else None
            break_end = datetime.strptime(f"{date_str} {doctor.break_end_time}", '%Y-%m-%d %H:%M') if doctor.break_end_time else None
        except ValueError:
            return Response({"error": "Doctor shift times are misconfigured"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # Fetch existing booked appointments for the day
        booked_appts = Appointment.objects.filter(
            doctor_id=doctor_id, 
            appointment_date=date_obj,
            booking_status__in=['confirmed', 'pendingPayment', 'rescheduled']
        )
        booked_times = [(a.slot_start_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None), 
                         a.slot_end_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None)) 
                        for a in booked_appts]
                        
        # Fetch doctor leaves/unavailability
        leaves = DoctorUnavailability.objects.filter(
            doctor_id=doctor_id,
            end_time__gt=timezone.make_aware(datetime.combine(date_obj, datetime.min.time())),
            start_time__lt=timezone.make_aware(datetime.combine(date_obj, datetime.max.time()))
        )
        leave_times = [(l.start_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None),
                        l.end_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None),
                        l.reason) for l in leaves]

        duration = timedelta(minutes=doctor.slot_duration_minutes)
        current = start_time
        
        while current + duration <= end_time:
            slot_end = current + duration
            is_break = break_start and break_end and (current >= break_start and current < break_end)
            
            is_booked = any((current >= b_start and current < b_end) or (slot_end > b_start and slot_end <= b_end) for b_start, b_end in booked_times)
            is_past = current < datetime.now()
            
            leave_reason = None
            is_leave = False
            for l_start, l_end, reason in leave_times:
                if (current >= l_start and current < l_end) or (slot_end > l_start and slot_end <= l_end):
                    is_leave = True
                    leave_reason = reason
                    break

            slots.append({
                "id": f"{doctor_id}_{current.strftime('%Y%m%d%H%M')}",
                "startTime": timezone.make_aware(current).isoformat(),
                "endTime": timezone.make_aware(slot_end).isoformat(),
                "doctorId": doctor_id,
                "isAvailable": not is_break and not is_booked and not is_past and not is_leave,
                "isBooked": is_booked,
                "isPast": is_past,
                "unavailabilityReason": leave_reason if is_leave else ("Break" if is_break else ("Booked" if is_booked else None))
            })
            current += duration

        return Response({"slots": slots})

    @action(detail=False, methods=['post'])
    def check_in(self, request):
        """
        Mark appointment as completed/arrived.
        Accepts either 'qr_payload' OR 'appointment_code'.
        """
        raw_payload = request.data.get('qr_payload')
        manual_code = request.data.get('appointment_code')
        
        if not raw_payload and not manual_code:
            return Response({"error": "Either qr_payload or appointment_code is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        appt = None
        
        if manual_code:
            try:
                appt = Appointment.objects.get(appointment_code=manual_code)
            except Appointment.DoesNotExist:
                return Response({"error": "Invalid appointment_code", "verified": False}, status=status.HTTP_404_NOT_FOUND)
        elif raw_payload:
            try:
                decoded = json.loads(raw_payload)
                code = decoded.get('code')
                signature = decoded.get('signature')
                appt = Appointment.objects.get(appointment_code=code)
                
                # Verify signature
                salt = getattr(settings, 'WEH_SECURE_AUTH_SALT', 'WEH_SECURE_AUTH_SALT_2026')
                date_str = appt.appointment_date.strftime('%Y-%m-%d')
                raw_message = f"{appt.appointment_code}|{appt.patient_id}|{appt.doctor_id}|{date_str}|{float(appt.consultation_fee):.2f}|{salt}"
                expected_sig = hashlib.sha256(raw_message.encode('utf-8')).hexdigest()
                
                if expected_sig != signature:
                    return Response({"error": "Invalid QR signature", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
            except (json.JSONDecodeError, Appointment.DoesNotExist):
                return Response({"error": "Invalid QR payload", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
                
        # Validate state
        if appt.booking_status == 'completed':
            return Response({"error": "Appointment is already checked in", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
        if appt.booking_status in ['cancelled', 'noShow']:
            return Response({"error": f"Appointment is {appt.booking_status}", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
            
        # Optional: check if payment is pending (for hospital desk payment flows, maybe they pay AT check-in)
            
        appt.booking_status = 'checkedIn'
        appt.checked_in_at = timezone.now()
        appt.save()

        # Audit Logging
        from apps.authentication.models import AuditLog
        AuditLog.objects.create(
            admin_user=request.user,
            action="Patient Check-In",
            details=f"Checked in appointment {appt.appointment_code} for patient {appt.patient_name}",
            ip_address=request.META.get('REMOTE_ADDR')
        )

        return Response({
            "message": "Check-in successful", 
            "verified": True, 
            "appointment": AppointmentSerializer(appt).data
        })

    @action(detail=True, methods=['post'])
    def cancel(self, request, id=None):
        """
        Patient-initiated cancellation.
        """
        appt = self.get_object()
        
        if appt.booking_status not in ['confirmed', 'gracePeriod']:
            return Response({"error": "Only upcoming appointments can be cancelled."}, status=status.HTTP_400_BAD_REQUEST)
            
        appt.booking_status = 'cancelled'
        appt.cancellation_reason = request.data.get('reason', 'Patient cancelled via app')
        appt.save()
        
        return Response({"message": "Appointment cancelled successfully."})

    @action(detail=True, methods=['post'])
    def reschedule(self, request, id=None):
        """
        Patient-initiated reschedule to a new date/time with the same doctor.
        Requires new_appointment_date and new_slot_start_time.
        """
        appt = self.get_object()
        
        if appt.booking_status not in ['confirmed', 'gracePeriod']:
            return Response({"error": "Only upcoming appointments can be rescheduled."}, status=status.HTTP_400_BAD_REQUEST)
            
        new_date_str = request.data.get('new_appointment_date')
        new_start_str = request.data.get('new_slot_start_time')
        
        if not new_date_str or not new_start_str:
            return Response({"error": "new_appointment_date and new_slot_start_time are required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            with transaction.atomic():
                doctor = Doctor.objects.select_for_update().get(id=appt.doctor_id)
                
                conflict = Appointment.objects.filter(
                    doctor_id=appt.doctor_id,
                    appointment_date=new_date_str,
                    slot_start_time=new_start_str,
                    booking_status__in=['confirmed', 'pendingPayment', 'completed']
                ).exclude(id=appt.id).exists()
                
                if conflict:
                    return Response({"error": "Slot unavailable"}, status=status.HTTP_409_CONFLICT)
                    
                # Calculate new end time based on doctor's slot duration
                new_start = datetime.fromisoformat(new_start_str.replace('Z', '+00:00'))
                new_end = new_start + timedelta(minutes=doctor.slot_duration_minutes)
                
                appt.appointment_date = new_date_str
                appt.slot_start_time = new_start
                appt.slot_end_time = new_end
                
                # Reset grace period and timestamps
                appt.grace_period_started_at = None
                appt.expires_at = None
                appt.checked_in_at = None
                appt.booking_status = 'confirmed' 
                
                # Regenerate code and QR
                appt.appointment_code = "" # trigger regeneration in save()
                appt.qr_signature = ""
                appt.save()
                
                return Response(AppointmentSerializer(appt).data)
                
        except IntegrityError:
            return Response({"error": "Slot unavailable"}, status=status.HTTP_409_CONFLICT)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
