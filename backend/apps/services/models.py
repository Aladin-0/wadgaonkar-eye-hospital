from django.db import models

class HospitalService(models.Model):
    id = models.CharField(max_length=64, primary_key=True, help_text="Unique service identifier e.g. srv_cataract")
    title = models.CharField(max_length=255)
    department = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    base_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    duration_minutes_override = models.PositiveIntegerField(blank=True, null=True, help_text="Overrides default doctor slot duration if set")
    icon_code = models.CharField(max_length=100, default='visibility')
    is_active = models.BooleanField(default=True)
    preparation_instructions = models.JSONField(blank=True, null=True, help_text="List of string instructions")

    class Meta:
        verbose_name = 'Hospital Service'
        verbose_name_plural = 'Hospital Services'
        ordering = ['department', 'title']

    def __str__(self):
        return f"{self.title} ({self.department})"

    def save(self, *args, **kwargs):
        if not self.id:
            import uuid
            self.id = f"srv_{uuid.uuid4().hex[:8]}"
        super().save(*args, **kwargs)

class FollowUpDiscountSetting(models.Model):
    is_active = models.BooleanField(default=True, help_text="Turn the 30-day follow-up discount on or off.")
    discount_percentage = models.PositiveIntegerField(default=30, help_text="Percentage discount to apply (e.g. 30 for 30%).")
    validity_days = models.PositiveIntegerField(default=30, help_text="Number of days the discount is valid after the first visit.")
    
    class Meta:
        verbose_name = 'Follow-Up Discount Setting'
        verbose_name_plural = 'Follow-Up Discount Settings'

    def __str__(self):
        status = "Active" if self.is_active else "Inactive"
        return f"{self.discount_percentage}% off within {self.validity_days} days ({status})"
        
    def save(self, *args, **kwargs):
        if not self.pk and FollowUpDiscountSetting.objects.exists():
            # Ensure only one instance exists (Singleton)
            return
        return super(FollowUpDiscountSetting, self).save(*args, **kwargs)
