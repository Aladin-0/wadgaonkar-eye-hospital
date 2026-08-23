from django.contrib import admin
from .models import Doctor, DoctorUnavailability

@admin.register(Doctor)
class DoctorAdmin(admin.ModelAdmin):
    list_display = ('name', 'specialization', 'consultation_fee', 'is_active')
    search_fields = ('name', 'specialization')
    list_filter = ('is_active', 'specialization')

@admin.register(DoctorUnavailability)
class DoctorUnavailabilityAdmin(admin.ModelAdmin):
    list_display = ('doctor', 'start_time', 'end_time', 'reason')
    search_fields = ('doctor__name', 'reason')
    list_filter = ('doctor',)
    date_hierarchy = 'start_time'
