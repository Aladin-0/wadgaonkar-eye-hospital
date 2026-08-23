from rest_framework import serializers
from .models import HospitalService

class HospitalServiceSerializer(serializers.ModelSerializer):
    base_fee = serializers.FloatField()

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
