from rest_framework import serializers
from .models import PaymentOrder

class PaymentOrderSerializer(serializers.ModelSerializer):
    amount = serializers.FloatField()

    class Meta:
        model = PaymentOrder
        fields = [
            'order_id',
            'appointment_id',
            'amount',
            'currency',
            'gateway_name',
            'gateway_order_id',
            'status',
            'patient_name',
            'patient_mobile',
            'patient_email',
            'notes',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']
