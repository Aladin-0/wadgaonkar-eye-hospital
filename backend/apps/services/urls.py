from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import HospitalServiceViewSet

router = DefaultRouter()
router.register('', HospitalServiceViewSet, basename='service')

urlpatterns = [
    path('', include(router.urls)),
]
