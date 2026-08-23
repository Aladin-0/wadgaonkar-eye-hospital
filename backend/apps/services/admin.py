from django.contrib import admin
from .models import HospitalService

@admin.register(HospitalService)
class HospitalServiceAdmin(admin.ModelAdmin):
    list_display = ('title', 'department', 'base_fee', 'is_active')
    search_fields = ('title', 'department')
    list_filter = ('is_active', 'department')
