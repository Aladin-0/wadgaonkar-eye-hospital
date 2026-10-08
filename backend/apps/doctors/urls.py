from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DoctorViewSet, DoctorUnavailabilityViewSet

router = DefaultRouter()
router.register('', DoctorViewSet, basename='doctor')

unavailability_router = DefaultRouter()
unavailability_router.register('', DoctorUnavailabilityViewSet, basename='unavailability')

urlpatterns = [
    path('unavailability/', include(unavailability_router.urls)),
    path('', include(router.urls)),
]
