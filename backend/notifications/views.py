from django.shortcuts import get_object_or_404
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response

from devices.models import Device
from .models import FCMToken
from .serializers import FCMTokenSerializer, FCMTokenRegisterSerializer
from .firebase_service import send_fcm_notification

class FCMTokenManageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_device(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        """Register or update an FCM token for an authorized device."""
        device = self.get_device(pk, request.user)
        serializer = FCMTokenRegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        raw_token = serializer.validated_data['token']

        # Check if token exists in database (prevent cross-user or multi-device duplicates)
        existing = FCMToken.objects.filter(token=raw_token).first()
        if existing:
            existing.user = request.user
            existing.device = device
            existing.is_active = True
            existing.save(update_fields=['user', 'device', 'is_active', 'updated_at'])
            token_record = existing
            created = False
        else:
            token_record = FCMToken.objects.create(
                user=request.user,
                device=device,
                token=raw_token,
                is_active=True
            )
            created = True

        res_serializer = FCMTokenSerializer(token_record)
        response_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response({
            "success": True,
            "message": "FCM registration token saved successfully.",
            "data": res_serializer.data
        }, status=response_status)

    def delete(self, request, pk):
        """Unregister/deactivate FCM token(s) for an authorized device."""
        device = self.get_device(pk, request.user)
        
        target_token = request.data.get('token') or request.query_params.get('token')

        if target_token:
            tokens_qs = FCMToken.objects.filter(device=device, token=target_token, is_active=True)
        else:
            tokens_qs = FCMToken.objects.filter(device=device, is_active=True)

        count = tokens_qs.count()
        tokens_qs.update(is_active=False)

        return Response({
            "success": True,
            "message": "FCM token(s) unregistered successfully.",
            "deactivated_count": count,
            "device_id": device.id
        }, status=status.HTTP_200_OK)


class FCMTestNotificationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_device(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        """Send a test push notification to an authorized device."""
        device = self.get_device(pk, request.user)

        title = request.data.get('title', 'TraceUp Test')
        body = request.data.get('body', f"Test notification for device '{device.name}'.")

        result = send_fcm_notification(
            device=device,
            title=title,
            body=body,
            data={
                "type": "test_notification",
                "device_id": str(device.id)
            }
        )

        if result.get("success"):
            return Response({
                "success": True,
                "message": f"Test FCM notification sent to '{device.name}'.",
                "result": result
            }, status=status.HTTP_200_OK)
        else:
            if result.get("error") == "No active FCM token registered for this device.":
                http_status = status.HTTP_400_BAD_REQUEST
            else:
                http_status = status.HTTP_503_SERVICE_UNAVAILABLE

            return Response({
                "success": False,
                "message": "Failed to send test FCM notification.",
                "error": result.get("error"),
                "result": result
            }, status=http_status)
