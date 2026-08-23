from rest_framework import serializers
from .models import Appointment

class AppointmentSerializer(serializers.ModelSerializer):
    consultation_fee = serializers.FloatField()

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
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['appointment_code', 'qr_payload', 'qr_signature', 'created_at', 'updated_at']
