from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from devices.models import Device

class Location(models.Model):
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='locations')
    latitude = models.FloatField(validators=[MinValueValidator(-90.0), MaxValueValidator(90.0)])
    longitude = models.FloatField(validators=[MinValueValidator(-180.0), MaxValueValidator(180.0)])
    accuracy = models.FloatField(default=0.0)
    timestamp = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"Device {self.device_id} at ({self.latitude}, {self.longitude}) at {self.timestamp}"
