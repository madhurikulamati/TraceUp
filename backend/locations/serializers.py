from rest_framework import serializers
from .models import Location

class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ('id', 'device', 'latitude', 'longitude', 'accuracy', 'timestamp')
        read_only_fields = ('id', 'device')

    def validate_latitude(self, value):
        if not (-90.0 <= value <= 90.0):
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value

    def validate_longitude(self, value):
        if not (-180.0 <= value <= 180.0):
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value
