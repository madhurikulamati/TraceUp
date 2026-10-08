from rest_framework import serializers
from .models import Device

class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = (
            'id',
            'user',
            'name',
            'device_type',
            'device_identifier',
            'is_online',
            'battery_level',
            'last_seen',
            'is_lost_mode',
            'lost_mode_enabled_at',
            'lost_mode_updated_at',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'user', 'last_seen', 'is_lost_mode', 'lost_mode_enabled_at', 'lost_mode_updated_at', 'created_at', 'updated_at')

    def validate_name(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Device name cannot be blank.")
        return value.strip()

    def validate_device_type(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Device type cannot be blank.")
        return value.strip()

    def validate_device_identifier(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Device identifier cannot be blank.")
        return value.strip()

    def validate_battery_level(self, value):
        if value is not None:
            if value < 0 or value > 100:
                raise serializers.ValidationError("Battery level must be between 0 and 100.")
        return value

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)
