from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import HospitalServiceViewSet, DiscountSettingView

router = DefaultRouter()
router.register('', HospitalServiceViewSet, basename='service')

urlpatterns = [
    path('discount_setting/', DiscountSettingView.as_view(), name='discount-setting'),
    path('', include(router.urls)),
]
