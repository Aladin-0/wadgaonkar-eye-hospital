from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.models import User
from .models import PatientProfile
from .serializers import PatientProfileSerializer, FirebaseSyncSerializer

class FirebaseSyncView(APIView):
    """
    Syncs Firebase Auth identity with local PatientProfile.
    Returns JWT access/refresh pair + profile metadata.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = FirebaseSyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        uid = data['uid']
        email = data.get('email') or f"{uid}@patient.wadgaonkar.local"
        display_name = data.get('display_name') or 'Hospital Patient'
        mobile = data.get('mobile_number') or ''

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
                'is_profile_complete': bool(mobile and display_name and display_name != 'Hospital Patient'),
            }
        )

        if not created and not profile.user:
            profile.user = user
            profile.save(update_fields=['user'])

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
