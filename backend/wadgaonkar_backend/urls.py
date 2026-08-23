"""
Root URL Configuration for Wadgaonkar Eye Hospital Backend.
"""
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse

from rest_framework_simplejwt.views import TokenObtainPairView

def api_health_check(request):
    return JsonResponse({
        'hospital': 'Wadgaonkar Eye Hospital',
        'status': 'operational',
        'api_version': 'v1',
        'timestamp': '2026-08-05T22:15:00',
    })

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', api_health_check, name='api-health'),
    path('api/v1/auth/admin/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/v1/auth/', include('apps.authentication.urls')),
    path('api/v1/doctors/', include('apps.doctors.urls')),
    path('api/v1/services/', include('apps.services.urls')),
    path('api/v1/appointments/', include('apps.appointments.urls')),
    path('api/v1/payments/', include('apps.payments.urls')),
]

# Customize Admin Site Headers
admin.site.site_header = "Wadgaonkar Eye Hospital OPD Administration"
admin.site.site_title = "WEH Portal"
admin.site.index_title = "Hospital Clinical Management System"
