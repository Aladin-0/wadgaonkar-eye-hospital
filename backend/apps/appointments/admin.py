from django.contrib import admin
from .models import Appointment

@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = ('appointment_code', 'patient_name', 'doctor_name', 'appointment_date', 'slot_start_time', 'booking_status', 'payment_status')
    search_fields = ('appointment_code', 'patient_name', 'patient_mobile', 'doctor_name', 'patient_id')
    list_filter = ('booking_status', 'payment_status', 'appointment_date', 'doctor_name')
    date_hierarchy = 'appointment_date'
    readonly_fields = ('appointment_code', 'qr_payload', 'qr_signature', 'created_at', 'updated_at')
