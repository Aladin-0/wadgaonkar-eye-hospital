from rest_framework import serializers
from .models import Doctor, DoctorUnavailability

class DoctorSerializer(serializers.ModelSerializer):
    consultation_fee = serializers.FloatField(required=False)

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
        extra_kwargs = {
            'qualification': {'required': False},
            'experience_years': {'required': False},
            'slot_duration_minutes': {'required': False},
            'working_days': {'required': False},
            'shift_start_time': {'required': False},
            'shift_end_time': {'required': False},
            'supported_service_ids': {'required': False},
        }

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if not ret.get('working_days'):
            ret['working_days'] = [1, 2, 3, 4, 5, 6]
        return ret

class DoctorUnavailabilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorUnavailability
        fields = ['id', 'doctor', 'start_time', 'end_time', 'reason']
