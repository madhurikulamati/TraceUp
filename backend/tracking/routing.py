from django.urls import path
from .consumers import TrackingConsumer

websocket_urlpatterns = [
    path('ws/devices/<int:device_id>/', TrackingConsumer.as_asgi(), name='ws-device-tracking'),
]
