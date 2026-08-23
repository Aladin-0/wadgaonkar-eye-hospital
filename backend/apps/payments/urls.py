from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import PaymentOrderViewSet

router = DefaultRouter()
router.register('', PaymentOrderViewSet, basename='payment')

urlpatterns = [
    path('', include(router.urls)),
]
