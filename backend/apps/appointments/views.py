import json
import hashlib
from datetime import datetime, timedelta, timezone as dt_timezone
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
from apps.services.models import HospitalService

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
            uid = self.request.query_params.get('patient_uid')
            if uid:
                qs = qs.filter(patient_uid=uid)
            elif self.action in ['retrieve', 'partial_update', 'update', 'destroy', 'cancel', 'reschedule']:
                # Allow access by ID for specific actions since Flutter doesn't pass patient_uid in URL for PATCH
                pass
            else:
                qs = Appointment.objects.none()
        return qs

    def get_permissions(self):
        # Patient-facing actions (no auth required)
        patient_actions = ['list', 'retrieve', 'create', 'partial_update', 'slots', 'cancel', 'reschedule', 'metadata']
        action = getattr(self, 'action', None)
        if action in patient_actions:
            return [permissions.AllowAny()]
        # Admin-only actions
        return [permissions.IsAdminUser()]

    def get_authenticators(self):
        if hasattr(self, 'request'):
            path = self.request.path
            
            # Explicitly require auth for admin actions
            if 'check_in' in path:
                return super().get_authenticators()
            
            # Patient reading history
            query_params = getattr(self.request, 'query_params', self.request.GET)
            if self.request.method == 'GET' and 'patient_uid' in query_params:
                return []
                
            # Patient booking appointment
            if self.request.method == 'POST' and path.endswith('/appointments/'):
                return []

            # Other patient actions
            if any(endpoint in path for endpoint in ['/slots', '/cancel', '/reschedule']):
                return []
                
        # Default to requiring auth (Admin reading history, etc)
        return super().get_authenticators()

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
                
                # 3. Calculate proper fee to prevent client spoofing
                from apps.services.models import HospitalService, FollowUpDiscountSetting
                from datetime import timedelta
                
                try:
                    service = HospitalService.objects.get(id=data.get('service_id'))
                    base_fee = service.base_fee
                    final_fee = base_fee
                    
                    setting = FollowUpDiscountSetting.objects.first()
                    if setting and setting.is_active:
                        cutoff_date = appt_date - timedelta(days=setting.validity_days)
                        past_booking = Appointment.objects.filter(
                            patient_uid=data.get('patient_uid'),
                            appointment_date__gte=cutoff_date,
                            appointment_date__lt=appt_date,
                            booking_status__in=['confirmed', 'completed', 'checkedIn']
                        ).exists()
                        if past_booking:
                            discount = (base_fee * setting.discount_percentage) / 100
                            final_fee = base_fee - discount
                except Exception:
                    final_fee = data.get('consultation_fee')

                # 4. Create the appointment. The UniqueConstraint in models.py acts as a secondary safety net.
                serializer.save(
                    booking_status='pendingPayment',
                    payment_status='pending',
                    consultation_fee=final_fee
                )
                
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
        # Enforce Sunday as a strict holiday regardless of doctor configuration
        weekday = date_obj.isoweekday()
        working_days = doctor.working_days if doctor.working_days else [1, 2, 3, 4, 5, 6]
        if weekday == 7 or weekday not in working_days:
            return Response({"slots": []})

        slots = []
        try:
            start_time = datetime.strptime(f"{date_str} {doctor.shift_start_time}", '%Y-%m-%d %H:%M')
            end_time = datetime.strptime(f"{date_str} {doctor.shift_end_time}", '%Y-%m-%d %H:%M')
            if doctor.break_start_time and doctor.break_end_time:
                break_start = datetime.strptime(f"{date_str} {doctor.break_start_time}", '%Y-%m-%d %H:%M')
                break_end = datetime.strptime(f"{date_str} {doctor.break_end_time}", '%Y-%m-%d %H:%M')
            else:
                break_start = None
                break_end = None
        except ValueError:
            return Response({"error": "Doctor shift times are misconfigured"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # Fetch existing booked appointments for the day
        booked_appts = Appointment.objects.filter(
            doctor_id=doctor_id, 
            appointment_date=date_obj,
            booking_status__in=['confirmed', 'pendingPayment', 'rescheduled']
        )
        booked_times = []
        for a in booked_appts:
            mobile = a.patient_mobile
            age = a.patient_age
            gender = a.patient_gender
            try:
                from apps.authentication.models import PatientProfile
                profile = PatientProfile.objects.get(uid=a.patient_uid)
                if profile.mobile_number: mobile = profile.mobile_number
                if profile.age: age = profile.age
                if profile.gender: gender = profile.gender
            except Exception:
                pass
                
            booked_times.append({
                'start_time': a.slot_start_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None).isoformat(),
                'end_time': a.slot_end_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None).isoformat(),
                'appointment_date': a.appointment_date.isoformat(),
                'id': a.id,
                'patient_name': a.patient_name,
                'patient_mobile': mobile,
                'appointment_code': a.appointment_code,
                'patient_age': age,
                'patient_gender': gender,
                'doctor_name': a.doctor_name,
                'service_title': a.service_title,
                'consultation_fee': str(a.consultation_fee),
                'status': a.booking_status
            })
                        
        # Fetch doctor leaves/unavailability
        leaves = DoctorUnavailability.objects.filter(
            doctor_id=doctor_id,
            end_time__gt=timezone.make_aware(datetime.combine(date_obj, datetime.min.time())),
            start_time__lt=timezone.make_aware(datetime.combine(date_obj, datetime.max.time()))
        )
        leave_times = [(l.start_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None),
                        l.end_time.astimezone(timezone.get_current_timezone()).replace(tzinfo=None),
                        l.reason, l.id) for l in leaves]

        service_id = request.query_params.get('service_id')
        service = None
        if service_id:
            try:
                service = HospitalService.objects.get(id=service_id)
            except HospitalService.DoesNotExist:
                pass

        if service and service.duration_minutes_override:
            duration = timedelta(minutes=service.duration_minutes_override)
        else:
            duration = timedelta(minutes=doctor.slot_duration_minutes)
        current = start_time
        
        while current + duration <= end_time:
            slot_end = current + duration
            is_break = False
            
            # Check if this slot intersects with the break time
            if break_start and break_end:
                if (current >= break_start and current < break_end) or (slot_end > break_start and slot_end <= break_end) or (current <= break_start and slot_end >= break_end):
                    is_break = True
            
            overlapping_appts = []
            for b in booked_times:
                b_start = datetime.fromisoformat(b['start_time'])
                b_end = datetime.fromisoformat(b['end_time'])
                if (current >= b_start and current < b_end) or (slot_end > b_start and slot_end <= b_end):
                    overlapping_appts.append({
                        "id": str(b['id']),
                        "patientName": b['patient_name'],
                        "patientMobile": b['patient_mobile'],
                        "appointmentCode": b['appointment_code'],
                        "patientAge": b['patient_age'],
                        "patientGender": b['patient_gender'],
                        "doctorName": b['doctor_name'],
                        "serviceTitle": b['service_title'],
                        "consultationFee": b['consultation_fee'],
                        "appointmentDate": b['appointment_date'],
                        "startTime": b['start_time'],
                        "endTime": b['end_time'],
                        "status": b['status']
                    })
                    
            is_booked = len(overlapping_appts) > 0
            is_past = timezone.make_aware(current) < timezone.now()
            
            leave_reason = None
            leave_id = None
            is_leave = False
            for l_start, l_end, reason, l_id in leave_times:
                if (current >= l_start and current < l_end) or (slot_end > l_start and slot_end <= l_end):
                    is_leave = True
                    leave_reason = reason
                    leave_id = l_id
                    break

            slot_data = {
                "id": f"{doctor_id}_{current.strftime('%Y%m%d%H%M')}",
                "startTime": timezone.make_aware(current).isoformat(),
                "endTime": timezone.make_aware(slot_end).isoformat(),
                "doctorId": doctor_id,
                "isAvailable": not is_break and not is_booked and not is_past and not is_leave,
                "isBooked": is_booked,
                "isPast": is_past,
                "unavailabilityReason": leave_reason if is_leave else ("Break" if is_break else ("Booked" if is_booked else None)),
                "unavailabilityId": leave_id if is_leave else None
            }
            if is_booked and request.user and request.user.is_staff:
                slot_data["bookedAppointments"] = overlapping_appts
                
            slots.append(slot_data)
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
        is_preview = request.data.get('preview', False)
        
        if not raw_payload and not manual_code:
            return Response({"error": "Either qr_payload or appointment_code is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        appt = None
        
        if manual_code:
            try:
                # If they enter just the suffix/shortcode, match the end of the code
                if len(manual_code) <= 8 and not manual_code.startswith('WEH-'):
                    appt = Appointment.objects.get(appointment_code__endswith=manual_code)
                else:
                    appt = Appointment.objects.get(appointment_code=manual_code)
            except Appointment.DoesNotExist:
                return Response({"error": "Invalid appointment_code", "verified": False}, status=status.HTTP_404_NOT_FOUND)
            except Appointment.MultipleObjectsReturned:
                return Response({"error": "Multiple appointments match this short code. Please enter the full code.", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
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
        if appt.booking_status == 'checkedIn':
            return Response({"error": "This QR was already scanned.", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
        if appt.booking_status == 'completed':
            return Response({"error": "Appointment is already completed", "verified": False}, status=status.HTTP_400_BAD_REQUEST)
        if appt.booking_status in ['cancelled', 'noShow', 'expired']:
            return Response({"error": f"Appointment is {appt.booking_status}", "verified": False}, status=status.HTTP_400_BAD_REQUEST)

        # If it is just a preview, return the appointment data without modifying it
        if is_preview:
            return Response({
                "message": "Preview successful", 
                "verified": True, 
                "appointment": AppointmentSerializer(appt).data
            })
            
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
        
        if appt.booking_status not in ['confirmed', 'gracePeriod', 'needsReschedule']:
            return Response({"error": "Only upcoming or cancelled emergency appointments can be rescheduled."}, status=status.HTTP_400_BAD_REQUEST)
            
        new_date_str = request.data.get('new_appointment_date')
        new_start_str = request.data.get('new_slot_start_time')
        
        if not new_date_str or not new_start_str:
            return Response({"error": "new_appointment_date and new_slot_start_time are required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            with transaction.atomic():
                doctor = Doctor.objects.select_for_update().get(id=appt.doctor_id)
                
                # Parse the incoming datetime string — Flutter sends ISO8601 with timezone offset
                try:
                    new_start = datetime.fromisoformat(new_start_str.replace('Z', '+00:00'))
                except ValueError:
                    return Response({"error": "Invalid new_slot_start_time format"}, status=status.HTTP_400_BAD_REQUEST)
                
                # Normalize to UTC for storage and comparison
                if new_start.tzinfo is None:
                    # Naive datetime — assume UTC
                    new_start_utc = new_start.replace(tzinfo=dt_timezone.utc)
                else:
                    # Timezone-aware — convert to UTC
                    new_start_utc = new_start.astimezone(dt_timezone.utc)
                new_end_utc = new_start_utc + timedelta(minutes=doctor.slot_duration_minutes)
                
                # Check conflicts using the normalized UTC time
                conflict = Appointment.objects.filter(
                    doctor_id=appt.doctor_id,
                    appointment_date=new_date_str,
                    slot_start_time=new_start_utc,
                    booking_status__in=['confirmed', 'pendingPayment', 'completed']
                ).exclude(id=appt.id).exists()
                
                if conflict:
                    return Response({"error": "Slot unavailable"}, status=status.HTTP_409_CONFLICT)
                
                try:
                    from datetime import date as date_type
                    new_date_obj = date_type.fromisoformat(new_date_str)
                except ValueError:
                    return Response({"error": "Invalid new_appointment_date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

                appt.appointment_date = new_date_obj
                appt.slot_start_time = new_start_utc
                appt.slot_end_time = new_end_utc
                
                # Reset grace period and timestamps
                appt.grace_period_started_at = None
                appt.expires_at = None
                appt.checked_in_at = None
                appt.booking_status = 'confirmed'
                appt.requires_rescheduling = False
                
                # Mark as rescheduled by patient so admin can see it
                from django.utils import timezone as tz
                appt.rescheduled_at = tz.now()
                
                # Regenerate code and QR
                appt.appointment_code = ""  # trigger regeneration in save()
                appt.qr_signature = ""
                appt.save()
                
                return Response(AppointmentSerializer(appt).data)
                
        except IntegrityError:
            return Response({"error": "Slot unavailable"}, status=status.HTTP_409_CONFLICT)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
