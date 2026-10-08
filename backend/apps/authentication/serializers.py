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
            'fcm_token',
            'created_at',
            'updated_at',
        'latest_appointment_code',
        'latest_service_title',
        'latest_doctor_name',
        'latest_appointment_date',
        'latest_start_time',
        'latest_end_time',
        'latest_service_fee',
    ]
    read_only_fields = ['patient_id', 'created_at', 'updated_at']
    
    latest_appointment_code = serializers.SerializerMethodField()
    latest_service_title = serializers.SerializerMethodField()
    latest_doctor_name = serializers.SerializerMethodField()
    latest_appointment_date = serializers.SerializerMethodField()
    latest_start_time = serializers.SerializerMethodField()
    latest_end_time = serializers.SerializerMethodField()
    latest_service_fee = serializers.SerializerMethodField()
    
    def _get_latest_appointment(self, obj):
        from apps.appointments.models import Appointment
        if not hasattr(obj, '_cached_latest_appt'):
            obj._cached_latest_appt = Appointment.objects.filter(patient_uid=obj.uid).order_by('-created_at').first()
        return obj._cached_latest_appt

    def get_latest_appointment_code(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.appointment_code if appt else None
        
    def get_latest_service_title(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.service_title if appt else None
        
    def get_latest_doctor_name(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.doctor_name if appt else None
        
    def get_latest_appointment_date(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.appointment_date if appt else None
        
    def get_latest_start_time(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.slot_start_time if appt else None
        
    def get_latest_end_time(self, obj):
        appt = self._get_latest_appointment(obj)
        return appt.slot_end_time if appt else None
        
    def get_latest_service_fee(self, obj):
        appt = self._get_latest_appointment(obj)
        return str(appt.consultation_fee) if appt else None

class FirebaseSyncSerializer(serializers.Serializer):
    uid = serializers.CharField(max_length=128)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    display_name = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)
    mobile_number = serializers.CharField(max_length=20, required=False, allow_blank=True, allow_null=True)
    age = serializers.IntegerField(required=False, allow_null=True)
    photo_url = serializers.URLField(required=False, allow_blank=True, allow_null=True)
    fcm_token = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)
