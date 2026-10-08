from django.shortcuts import get_object_or_404
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response

from devices.models import Device
from .redis_service import RedisService

class DeviceStateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_device(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        device = self.get_device(pk, request.user)
        device_status = request.data.get('status', 'online')
        battery_level = request.data.get('battery_level', device.battery_level)
        ttl = request.data.get('ttl', 300)

        try:
            ttl = int(ttl)
            if ttl <= 0:
                return Response({'ttl': ['TTL must be a positive integer in seconds.']}, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError):
            return Response({'ttl': ['TTL must be a valid integer.']}, status=status.HTTP_400_BAD_REQUEST)

        if battery_level is not None:
            try:
                battery_level = int(battery_level)
                if not (0 <= battery_level <= 100):
                    return Response({'battery_level': ['Battery level must be between 0 and 100.']}, status=status.HTTP_400_BAD_REQUEST)
            except (ValueError, TypeError):
                return Response({'battery_level': ['Battery level must be an integer.']}, status=status.HTTP_400_BAD_REQUEST)

        state = RedisService.set_device_state(
            device_id=device.id,
            status=device_status,
            battery_level=battery_level,
            ttl=ttl
        )
        return Response(state, status=status.HTTP_200_OK)

    def get(self, request, pk):
        device = self.get_device(pk, request.user)
        state = RedisService.get_device_state(device.id)
        if not state:
            return Response({'detail': 'No active temporary state found for this device in Redis.'}, status=status.HTTP_404_NOT_FOUND)
        
        ttl = RedisService.get_ttl(device.id)
        state['ttl_remaining'] = ttl
        return Response(state, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        device = self.get_device(pk, request.user)
        deleted = RedisService.delete_device_state(device.id)
        return Response({'success': True, 'deleted': bool(deleted)}, status=status.HTTP_200_OK)
