from django.db import models
from django.conf import settings

class Device(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='devices')
    name = models.CharField(max_length=255)
    device_type = models.CharField(max_length=100, default='android')
    device_identifier = models.CharField(max_length=255, unique=True)
    is_online = models.BooleanField(default=False)
    battery_level = models.IntegerField(default=100)
    last_seen = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.device_identifier})"
