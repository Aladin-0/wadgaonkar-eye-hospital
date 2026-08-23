from rest_framework import serializers
from .models import Doctor

class DoctorSerializer(serializers.ModelSerializer):
    consultation_fee = serializers.FloatField()

    class Meta:
        model = Doctor
        fields = [
            'id',
            'name',
            'qualification',
            'specialization',
            'experience_years',
            'profile_image_url',
            'consultation_fee',
            'slot_duration_minutes',
            'working_days',
            'shift_start_time',
            'shift_end_time',
            'break_start_time',
            'break_end_time',
            'is_active',
            'supported_service_ids',
            'bio',
            'created_at',
            'updated_at',
        ]
