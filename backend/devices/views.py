from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination

from .models import Device
from .serializers import DeviceSerializer
from locations.models import Location
from locations.serializers import LocationSerializer

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

class DeviceLocationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_device(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        device = self.get_device(pk, request.user)
        serializer = LocationSerializer(data=request.data)
        if serializer.is_valid():
            location = serializer.save(device=device)
            # Update device last_seen and online state
            now = timezone.now()
            device.last_seen = location.timestamp or now
            device.is_online = True
            device.save(update_fields=['last_seen', 'is_online', 'updated_at'])

            return Response({
                "success": True,
                "timestamp": location.timestamp.isoformat()
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def get(self, request, pk):
        device = self.get_device(pk, request.user)
        latest_location = device.locations.first()
        if not latest_location:
            return Response({'message': 'No location data found for this device.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = LocationSerializer(latest_location)
        return Response(serializer.data, status=status.HTTP_200_OK)

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class DeviceLocationHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        device = get_object_or_404(Device, id=pk, user=request.user)
        locations = device.locations.all()
        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(locations, request)
        if page is not None:
            serializer = LocationSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

class DeviceRingView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        device = get_object_or_404(Device, id=pk, user=request.user)
        return Response({
            "success": True,
            "message": f"Ring command sent to device '{device.name}'"
        }, status=status.HTTP_200_OK)

class DeviceLostModeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        device = get_object_or_404(Device, id=pk, user=request.user)
        return Response({
            "success": True,
            "message": f"Lost mode command sent to device '{device.name}'"
        }, status=status.HTTP_200_OK)
