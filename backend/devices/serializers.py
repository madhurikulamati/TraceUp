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
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'user', 'last_seen', 'created_at', 'updated_at')

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)
