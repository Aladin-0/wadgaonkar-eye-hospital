from rest_framework import viewsets, permissions
from .models import HospitalService
from .serializers import HospitalServiceSerializer

class HospitalServiceViewSet(viewsets.ModelViewSet):
    """
    Hospital Services ViewSet.
    Public list and retrieve, authenticated admin for CRUD.
    """
    serializer_class = HospitalServiceSerializer
    lookup_field = 'id'

    def get_queryset(self):
        qs = HospitalService.objects.all()
        # Default public users only see active services
        if not (self.request.user and self.request.user.is_staff):
            qs = qs.filter(is_active=True)
        return qs

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]
