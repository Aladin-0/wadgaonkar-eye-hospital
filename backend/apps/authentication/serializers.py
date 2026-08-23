from rest_framework import serializers
from .models import PatientProfile

class PatientProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientProfile
        fields = [
            'uid',
            'full_name',
            'mobile_number',
            'email',
            'age',
            'gender',
            'patient_id',
            'city',
            'blood_group',
            'photo_url',
            'address',
            'pincode',
            'emergency_contact',
            'medical_notes',
            'is_profile_complete',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['patient_id', 'created_at', 'updated_at']

class FirebaseSyncSerializer(serializers.Serializer):
    uid = serializers.CharField(max_length=128)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    display_name = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)
    mobile_number = serializers.CharField(max_length=20, required=False, allow_blank=True, allow_null=True)
    photo_url = serializers.URLField(required=False, allow_blank=True, allow_null=True)
