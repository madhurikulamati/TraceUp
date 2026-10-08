from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response

from devices.models import Device
from .models import Location
from .serializers import LocationSerializer

class DeviceLocationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_device(self, pk, user):
        return get_object_or_404(Device, id=pk, user=user)

    def post(self, request, pk):
        device = self.get_device(pk, request.user)
        serializer = LocationSerializer(data=request.data)
        if serializer.is_valid():
            location = serializer.save(device=device)
            # Update device status and last_seen timestamp
            now = timezone.now()
            device.last_seen = location.timestamp or now
            device.is_online = True
            device.save(update_fields=['last_seen', 'is_online', 'updated_at'])

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def get(self, request, pk):
        device = self.get_device(pk, request.user)
        latest_location = device.locations.first()
        if not latest_location:
            return Response({'message': 'No location data found for this device.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = LocationSerializer(latest_location)
        return Response(serializer.data, status=status.HTTP_200_OK)

class DeviceLocationHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        device = get_object_or_404(Device, id=pk, user=request.user)
        locations = device.locations.all()
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
