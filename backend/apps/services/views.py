from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import HospitalService, FollowUpDiscountSetting
from .serializers import HospitalServiceSerializer

class DiscountSettingView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        setting, _ = FollowUpDiscountSetting.objects.get_or_create(id=1)
        return Response({
            "is_active": setting.is_active,
            "discount_percentage": setting.discount_percentage,
            "validity_days": setting.validity_days,
        })

    def patch(self, request):
        setting, _ = FollowUpDiscountSetting.objects.get_or_create(id=1)
        if 'is_active' in request.data:
            setting.is_active = request.data['is_active']
        if 'discount_percentage' in request.data:
            setting.discount_percentage = int(request.data['discount_percentage'])
        if 'validity_days' in request.data:
            setting.validity_days = int(request.data['validity_days'])
        setting.save()
        return Response({
            "is_active": setting.is_active,
            "discount_percentage": setting.discount_percentage,
            "validity_days": setting.validity_days,
        })

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
        if self.action in ['list', 'retrieve', 'calculate_fee']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    @action(detail=True, methods=['get'])
    def calculate_fee(self, request, id=None):
        service = self.get_object()
        patient_uid = request.query_params.get('patient_uid')
        appointment_date_str = request.query_params.get('date')
        
        original_fee = service.base_fee
        final_fee = original_fee
        discount_applied = False
        message = ""
        
        if not patient_uid or not appointment_date_str:
            return Response(
                {"error": "patient_uid and date are required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
            
        try:
            from datetime import datetime, timedelta
            from apps.appointments.models import Appointment
            from .models import FollowUpDiscountSetting
            
            appt_date = datetime.strptime(appointment_date_str, '%Y-%m-%d').date()
            
            setting = FollowUpDiscountSetting.objects.first()
            if setting and setting.is_active:
                cutoff_date = appt_date - timedelta(days=setting.validity_days)
                
                # Check for a past booking in the last 30 days
                past_booking = Appointment.objects.filter(
                    patient_uid=patient_uid,
                    appointment_date__gte=cutoff_date,
                    appointment_date__lt=appt_date,
                    booking_status__in=['confirmed', 'completed', 'checkedIn']
                ).exists()
                
                if past_booking:
                    discount_amount = (original_fee * setting.discount_percentage) / 100
                    final_fee = original_fee - discount_amount
                    discount_applied = True
                    message = f"30-Day Follow-Up Discount Applied ({setting.discount_percentage}% off)"
                    
        except Exception as e:
            pass # fallback to original fee
            
        return Response({
            "original_fee": original_fee,
            "final_fee": final_fee,
            "discount_applied": discount_applied,
            "message": message
        })
