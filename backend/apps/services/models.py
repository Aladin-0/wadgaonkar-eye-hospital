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
