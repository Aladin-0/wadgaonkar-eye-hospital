from django.contrib import admin
from .models import PatientProfile

@admin.register(PatientProfile)
class PatientProfileAdmin(admin.ModelAdmin):
    list_display = ('patient_id', 'full_name', 'mobile_number', 'city', 'is_profile_complete')
    search_fields = ('patient_id', 'full_name', 'mobile_number', 'uid')
    list_filter = ('is_profile_complete', 'city', 'blood_group')
    readonly_fields = ('created_at', 'updated_at', 'patient_id')
