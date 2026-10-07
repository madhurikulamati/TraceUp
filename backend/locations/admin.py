from django.contrib import admin
from .models import Location

@admin.register(Location)
class LocationAdmin(admin.ModelAdmin):
    list_display = ('id', 'device', 'latitude', 'longitude', 'accuracy', 'timestamp')
    list_filter = ('timestamp', 'device')
    search_fields = ('device__name', 'device__device_identifier')
