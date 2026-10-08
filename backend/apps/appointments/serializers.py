from rest_framework import serializers
from .models import Appointment

class AppointmentSerializer(serializers.ModelSerializer):
    consultation_fee = serializers.FloatField()
    is_rescheduled = serializers.SerializerMethodField()

    def get_is_rescheduled(self, obj):
        # An appointment is considered rescheduled if its appointment_code has changed
        # We detect this by checking if booking_status=='confirmed' and requires_rescheduling was True
        # Instead, we use a dedicated flag: rescheduled_at
        return getattr(obj, 'rescheduled_at', None) is not None

    def to_internal_value(self, data):
        # Handle flutter's toIso8601String() sending time for a DateField
        if 'appointment_date' in data and isinstance(data['appointment_date'], str) and 'T' in data['appointment_date']:
            data = data.copy()
            data['appointment_date'] = data['appointment_date'].split('T')[0]
        return super().to_internal_value(data)

    class Meta:
        model = Appointment
        fields = [
            'id',
            'appointment_code',
            'patient_uid',
            'patient_name',
            'patient_mobile',
            'patient_age',
            'patient_gender',
            'patient_id',
            'doctor_id',
            'doctor_name',
            'doctor_specialization',
            'doctor_qualification',
            'service_id',
            'service_title',
            'appointment_date',
            'slot_start_time',
            'slot_end_time',
            'consultation_fee',
            'booking_status',
            'payment_status',
            'payment_method',
            'payment_transaction_id',
            'qr_payload',
            'qr_signature',
            'cancellation_reason',
            'is_rescheduled',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['appointment_code', 'qr_payload', 'qr_signature', 'created_at', 'updated_at']
        extra_kwargs = {
            'doctor_specialization': {'required': False, 'allow_blank': True, 'allow_null': True},
            'doctor_qualification': {'required': False, 'allow_blank': True, 'allow_null': True},
            'patient_gender': {'required': False, 'allow_blank': True, 'allow_null': True},
            'patient_age': {'required': False},
            'patient_mobile': {'required': False, 'allow_blank': True, 'allow_null': True},
            'cancellation_reason': {'required': False, 'allow_blank': True, 'allow_null': True},
            'payment_transaction_id': {'required': False, 'allow_blank': True, 'allow_null': True},
            'payment_method': {'required': False, 'allow_blank': True, 'allow_null': True},
        }
