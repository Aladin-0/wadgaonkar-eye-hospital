from django.contrib import admin
from .models import PaymentOrder

@admin.register(PaymentOrder)
class PaymentOrderAdmin(admin.ModelAdmin):
    list_display = ('order_id', 'patient_name', 'amount', 'currency', 'status', 'created_at')
    search_fields = ('order_id', 'appointment_id', 'patient_name', 'patient_mobile')
    list_filter = ('status', 'gateway_name', 'created_at')
    date_hierarchy = 'created_at'
    readonly_fields = ('created_at', 'updated_at')
