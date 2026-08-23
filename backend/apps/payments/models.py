import uuid
from django.db import models
from django.utils import timezone

class PaymentOrder(models.Model):
    order_id = models.CharField(max_length=128, primary_key=True, default=uuid.uuid4)
    appointment_id = models.CharField(max_length=128, db_index=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=10, default='INR')
    gateway_name = models.CharField(max_length=50, default='Razorpay')
    gateway_order_id = models.CharField(max_length=128, blank=True, null=True)
    status = models.CharField(max_length=50, default='created') # created, paid, failed
    
    patient_name = models.CharField(max_length=255)
    patient_mobile = models.CharField(max_length=20)
    patient_email = models.EmailField(blank=True, null=True)
    
    notes = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.order_id} - {self.status} - {self.amount} {self.currency}"
