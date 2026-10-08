import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

from devices.models import Device
from locations.models import Location
from .redis_service import RedisService

@database_sync_to_async
def get_user_device(device_id, user):
    try:
        return Device.objects.get(id=device_id, user=user)
    except Device.DoesNotExist:
        return None

@database_sync_to_async
def save_location_and_update_device(device, latitude, longitude, accuracy):
    location = Location.objects.create(
        device=device,
        latitude=latitude,
        longitude=longitude,
        accuracy=accuracy
    )
    now = timezone.now()
    device.last_seen = location.timestamp or now
    device.is_online = True
    device.save(update_fields=['last_seen', 'is_online', 'updated_at'])

    # Update Redis temporary device state
    RedisService.set_device_state(
        device_id=device.id,
        status="online",
        battery_level=device.battery_level
    )

    return {
        "type": "location_update",
        "id": location.id,
        "device_id": device.id,
        "latitude": location.latitude,
        "longitude": location.longitude,
        "accuracy": location.accuracy,
        "timestamp": location.timestamp.isoformat()
    }

class TrackingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get('user', AnonymousUser())

        if not self.user or not self.user.is_authenticated:
            await self.close(code=4401)
            return

        self.device_id = self.scope['url_route']['kwargs'].get('device_id')
        self.device = await get_user_device(self.device_id, self.user)

        if not self.device:
            await self.close(code=4403)
            return

        self.group_name = f"traceup_device_{self.device_id}"

        # Join device-specific group
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data)
        except (ValueError, TypeError):
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "MALFORMED_JSON",
                "message": "Invalid JSON payload."
            }))
            return

        msg_type = data.get('type')
        if msg_type != 'location_update':
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "UNSUPPORTED_TYPE",
                "message": "Unsupported message type. Expected 'location_update'."
            }))
            return

        # Validate client device_id if sent in payload
        payload_device_id = data.get('device_id')
        if payload_device_id is not None and str(payload_device_id) != str(self.device_id):
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "DEVICE_ID_MISMATCH",
                "message": "Device ID in payload does not match connected endpoint."
            }))
            return

        # Coordinate & field validation
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        accuracy = data.get('accuracy', 0.0)

        if latitude is None or longitude is None:
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "MISSING_COORDINATES",
                "message": "Latitude and longitude are required."
            }))
            return

        try:
            latitude = float(latitude)
            longitude = float(longitude)
            accuracy = float(accuracy)
        except (ValueError, TypeError):
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "INVALID_COORDINATES_TYPE",
                "message": "Latitude, longitude, and accuracy must be numeric."
            }))
            return

        if not (-90.0 <= latitude <= 90.0):
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "INVALID_LATITUDE",
                "message": "Latitude must be between -90 and 90."
            }))
            return

        if not (-180.0 <= longitude <= 180.0):
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "INVALID_LONGITUDE",
                "message": "Longitude must be between -180 and 180."
            }))
            return

        if accuracy < 0:
            await self.send(text_data=json.dumps({
                "type": "error",
                "code": "INVALID_ACCURACY",
                "message": "Accuracy cannot be negative."
            }))
            return

        # Save location to PostgreSQL and update status
        payload = await save_location_and_update_device(self.device, latitude, longitude, accuracy)

        # Broadcast real-time update to group
        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "location_broadcast",
                "data": payload
            }
        )

    async def location_broadcast(self, event):
        await self.send(text_data=json.dumps(event['data']))
