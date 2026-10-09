from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

from .models import Device
from .serializers import DeviceSerializer

class DeviceListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        devices = Device.objects.filter(user=request.user)
        serializer = DeviceSerializer(devices, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = DeviceSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class DeviceDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def get(self, request, pk):
        device = self.get_object(pk, request.user)
        serializer = DeviceSerializer(device)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        device = self.get_object(pk, request.user)
        device.delete()
        return Response({'success': True, 'message': 'Device deleted successfully.'}, status=status.HTTP_200_OK)

class DeviceRingView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        device = self.get_object(pk, request.user)

        # Broadcast ring command to the device's WebSocket group
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"traceup_device_{device.id}",
                {
                    "type": "ring_command_broadcast",
                    "data": {
                        "type": "ring_command",
                        "device_id": device.id
                    }
                }
            )

        # Send FCM push notification (non-blocking fallback)
        try:
            from notifications.firebase_service import send_fcm_notification
            send_fcm_notification(
                device=device,
                title="TraceUp Ring Alert",
                body=f"Your device '{device.name}' is requested to ring.",
                data={
                    "type": "ring",
                    "device_id": str(device.id)
                }
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': f"Ring command sent to device '{device.name}'",
            'device_id': device.id
        }, status=status.HTTP_200_OK)

class DeviceLostModeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def get(self, request, pk):
        device = self.get_object(pk, request.user)
        return Response({
            'device_id': device.id,
            'is_lost_mode': device.is_lost_mode,
            'lost_mode_enabled_at': device.lost_mode_enabled_at.isoformat() if device.lost_mode_enabled_at else None,
            'lost_mode_updated_at': device.lost_mode_updated_at.isoformat() if device.lost_mode_updated_at else None,
        }, status=status.HTTP_200_OK)

    def post(self, request, pk):
        device = self.get_object(pk, request.user)
        now = timezone.now()
        device.is_lost_mode = True
        if not device.lost_mode_enabled_at:
            device.lost_mode_enabled_at = now
        device.lost_mode_updated_at = now
        device.save(update_fields=['is_lost_mode', 'lost_mode_enabled_at', 'lost_mode_updated_at', 'updated_at'])

        # Broadcast lost mode update to the device's WebSocket group
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"traceup_device_{device.id}",
                {
                    "type": "lost_mode_broadcast",
                    "data": {
                        "type": "lost_mode_update",
                        "device_id": device.id,
                        "is_lost_mode": True,
                        "lost_mode_enabled_at": device.lost_mode_enabled_at.isoformat() if device.lost_mode_enabled_at else None,
                        "lost_mode_updated_at": device.lost_mode_updated_at.isoformat() if device.lost_mode_updated_at else None,
                    }
                }
            )

        # Send FCM push notification for Lost Mode enable
        try:
            from notifications.firebase_service import send_fcm_notification
            send_fcm_notification(
                device=device,
                title="TraceUp Lost Mode",
                body=f"Lost Mode has been enabled for your device '{device.name}'.",
                data={
                    "type": "lost_mode_enabled",
                    "device_id": str(device.id),
                    "is_lost_mode": "true"
                }
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': f"Lost mode enabled for device '{device.name}'",
            'device_id': device.id,
            'is_lost_mode': True,
            'lost_mode_enabled_at': device.lost_mode_enabled_at.isoformat() if device.lost_mode_enabled_at else None,
            'lost_mode_updated_at': device.lost_mode_updated_at.isoformat() if device.lost_mode_updated_at else None,
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        device = self.get_object(pk, request.user)
        now = timezone.now()
        device.is_lost_mode = False
        device.lost_mode_updated_at = now
        device.save(update_fields=['is_lost_mode', 'lost_mode_updated_at', 'updated_at'])

        # Broadcast lost mode update to the device's WebSocket group
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"traceup_device_{device.id}",
                {
                    "type": "lost_mode_broadcast",
                    "data": {
                        "type": "lost_mode_update",
                        "device_id": device.id,
                        "is_lost_mode": False,
                        "lost_mode_updated_at": device.lost_mode_updated_at.isoformat() if device.lost_mode_updated_at else None,
                    }
                }
            )

        # Send FCM push notification for Lost Mode disable
        try:
            from notifications.firebase_service import send_fcm_notification
            send_fcm_notification(
                device=device,
                title="TraceUp Lost Mode",
                body=f"Lost Mode has been disabled for your device '{device.name}'.",
                data={
                    "type": "lost_mode_disabled",
                    "device_id": str(device.id),
                    "is_lost_mode": "false"
                }
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': f"Lost mode disabled for device '{device.name}'",
            'device_id': device.id,
            'is_lost_mode': False,
            'lost_mode_updated_at': device.lost_mode_updated_at.isoformat() if device.lost_mode_updated_at else None,
        }, status=status.HTTP_200_OK)



