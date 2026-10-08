from rest_framework import serializers
from .models import HospitalService

class HospitalServiceSerializer(serializers.ModelSerializer):
    base_fee = serializers.FloatField(required=False)

    class Meta:
        model = HospitalService
        fields = [
            'id',
            'title',
            'department',
            'description',
            'base_fee',
            'duration_minutes_override',
            'icon_code',
            'is_active',
            'preparation_instructions',
        ]
        extra_kwargs = {
            'id': {'required': False},
            'department': {'required': False, 'default': 'General'},
            'duration_minutes_override': {'required': False},
            'icon_code': {'required': False},
            'preparation_instructions': {'required': False},
        }
