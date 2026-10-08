from django.contrib import admin
from .models import HospitalService, FollowUpDiscountSetting

@admin.register(HospitalService)
class HospitalServiceAdmin(admin.ModelAdmin):
    list_display = ('title', 'department', 'base_fee', 'is_active')
    search_fields = ('title', 'department')
    list_filter = ('is_active', 'department')

@admin.register(FollowUpDiscountSetting)
class FollowUpDiscountSettingAdmin(admin.ModelAdmin):
    list_display = ('is_active', 'discount_percentage', 'validity_days')
    
    def has_add_permission(self, request):
        # Prevent adding multiple instances
        if self.model.objects.exists():
            return False
        return super().has_add_permission(request)
