from django.db import models
from django.conf import settings
from devices.models import Device

class FCMToken(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='fcm_tokens'
    )
    device = models.ForeignKey(
        Device,
        on_delete=models.CASCADE,
        related_name='fcm_tokens'
    )
    token = models.CharField(max_length=500, unique=True, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['device', 'is_active']),
            models.Index(fields=['user', 'is_active']),
        ]

    def __str__(self):
        token_snippet = self.token[:15] + "..." if len(self.token) > 15 else self.token
        return f"FCMToken({self.device.name}, active={self.is_active}, token={token_snippet})"
