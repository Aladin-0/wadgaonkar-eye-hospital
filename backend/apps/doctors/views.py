from rest_framework import viewsets, permissions
from .models import Doctor
from .serializers import DoctorSerializer

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
