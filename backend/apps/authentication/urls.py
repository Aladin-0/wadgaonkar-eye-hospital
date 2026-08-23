from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FirebaseSyncView, PatientProfileViewSet

router = DefaultRouter()
router.register('profiles', PatientProfileViewSet, basename='patient-profile')

urlpatterns = [
    path('firebase-sync/', FirebaseSyncView.as_view(), name='firebase-sync'),
    path('', include(router.urls)),
]
