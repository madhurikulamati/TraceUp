from rest_framework import serializers
from .models import FCMToken

class FCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = FCMToken
        fields = ['id', 'user', 'device', 'token', 'is_active', 'created_at', 'updated_at', 'last_used_at']
        read_only_fields = ['id', 'user', 'device', 'created_at', 'updated_at', 'last_used_at']

class FCMTokenRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(required=True, allow_blank=False, max_length=500)

    def validate_token(self, value):
        token = value.strip()
        if not token:
            raise serializers.ValidationError("FCM token cannot be empty or whitespace.")
        return token
