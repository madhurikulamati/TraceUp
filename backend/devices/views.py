from django.shortcuts import get_object_or_404
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response

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

