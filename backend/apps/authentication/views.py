from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.models import User
from .models import PatientProfile
from .serializers import PatientProfileSerializer, FirebaseSyncSerializer
from django.db import transaction

class FirebaseSyncView(APIView):
    """
    Syncs Firebase Auth identity with local PatientProfile.
    Returns JWT access/refresh pair + profile metadata.
    """
    permission_classes = [permissions.AllowAny]

    def get_authenticators(self):
        return []

    def post(self, request):
        serializer = FirebaseSyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        uid = data['uid']
        email = data.get('email') or f"{uid}@patient.wadgaonkar.local"
        display_name = data.get('display_name') or 'Hospital Patient'
        mobile = data.get('mobile_number') or ''
        age = data.get('age')

        # Ensure Django User exists
        user, _ = User.objects.get_or_create(
            username=uid,
            defaults={'email': email, 'first_name': display_name}
        )

        profile, created = PatientProfile.objects.get_or_create(
            uid=uid,
            defaults={
                'user': user,
                'full_name': display_name,
                'email': data.get('email'),
                'mobile_number': mobile,
                'age': age,
                'fcm_token': data.get('fcm_token'),
                'is_profile_complete': bool(mobile and age and display_name and display_name != 'Hospital Patient'),
            }
        )

        update_fields = []
        if not created and not profile.user:
            profile.user = user
            update_fields.append('user')
            
        fcm_token = data.get('fcm_token')
        if not created and fcm_token and profile.fcm_token != fcm_token:
            profile.fcm_token = fcm_token
            update_fields.append('fcm_token')

        if not created and mobile and profile.mobile_number != mobile:
            profile.mobile_number = mobile
            update_fields.append('mobile_number')

        if not created and age and profile.age != age:
            profile.age = age
            update_fields.append('age')
            
        if not created and display_name and profile.full_name != display_name:
            profile.full_name = display_name
            update_fields.append('full_name')

        if not created:
            profile.is_profile_complete = bool(profile.mobile_number and profile.age and profile.full_name and profile.full_name != 'Hospital Patient')
            update_fields.append('is_profile_complete')
            
        if update_fields:
            profile.save(update_fields=update_fields)

        # Generate SimpleJWT tokens
        refresh = RefreshToken.for_user(user)

        return Response({
            'success': True,
            'access_token': str(refresh.access_token),
            'refresh_token': str(refresh),
            'profile': PatientProfileSerializer(profile).data,
            'is_new_patient': created,
        }, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)

class PatientProfileViewSet(ModelViewSet):
    """
    Patient Profile ViewSet for retrieving and updating patient case records.
    """
    queryset = PatientProfile.objects.all()
    serializer_class = PatientProfileSerializer
    lookup_field = 'uid'

    def get_permissions(self):
        if self.action in ['create', 'retrieve', 'update', 'partial_update']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        return Response({
            'success': True,
            'data': self.get_serializer(instance).data
        })


class DeleteAccountView(APIView):
    """
    Permanently deletes the calling patient's account (App Store 5.1.1(v)).

    The caller must present a valid Firebase ID token. Personal identifiers are
    erased from the profile; appointment and payment rows are anonymised (not
    removed) because Indian medical/financial record-retention rules apply.
    """
    permission_classes = [permissions.AllowAny]

    def get_authenticators(self):
        return []

    def post(self, request):
        from apps.appointments.models import Appointment
        from apps.payments.models import PaymentOrder
        import firebase_admin.auth as fb_auth

        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer ') or len(header) <= 7:
            return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)
        try:
            uid = fb_auth.verify_id_token(header[7:]).get('uid')
        except Exception:
            return Response({'detail': 'Invalid or expired token.'}, status=status.HTTP_401_UNAUTHORIZED)
        if not uid:
            return Response({'detail': 'Invalid token.'}, status=status.HTTP_401_UNAUTHORIZED)

        with transaction.atomic():
            appt_ids = list(Appointment.objects.filter(patient_uid=uid).values_list('id', flat=True))
            Appointment.objects.filter(patient_uid=uid).update(
                patient_name='Deleted User',
                patient_mobile='',
                patient_gender=None,
                patient_uid=f'deleted-{uid[:8]}',
            )
            PaymentOrder.objects.filter(appointment_id__in=appt_ids).update(
                patient_name='Deleted User', patient_mobile='', patient_email=None,
            )
            PatientProfile.objects.filter(uid=uid).delete()
            User.objects.filter(username=uid, is_staff=False, is_superuser=False).delete()

        try:
            fb_auth.delete_user(uid)
        except Exception:
            pass  # already removed client-side or not found

        return Response({'success': True}, status=status.HTTP_200_OK)
