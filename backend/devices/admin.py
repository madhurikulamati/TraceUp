from django.contrib import admin
from .models import Device

@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'name', 'device_type', 'device_identifier', 'is_online', 'battery_level', 'last_seen', 'created_at')
    list_filter = ('is_online', 'device_type', 'created_at')
    search_fields = ('name', 'device_identifier', 'user__email')
