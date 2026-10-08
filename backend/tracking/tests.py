import time
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken

from devices.models import Device
from locations.models import Location
from tracking.redis_service import RedisService

from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from config.asgi import application
from tracking.consumers import TrackingConsumer

User = get_user_model()

class RedisIntegrationAPITestCase(TestCase):
    def setUp(self):
        self.unauthenticated_client = APIClient()
        self.client_a = APIClient()
        self.client_b = APIClient()

        self.user_a = User.objects.create_user(email="user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="user_b@example.com", name="User B", password="password123")

        self.client_a.force_authenticate(user=self.user_a)
        self.client_b.force_authenticate(user=self.user_b)

        self.device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        self.device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")

        self.state_url_a = reverse('device-state', kwargs={'pk': self.device_a.id})
        self.state_url_b = reverse('device-state', kwargs={'pk': self.device_b.id})

    def tearDown(self):
        RedisService.delete_device_state(self.device_a.id)
        RedisService.delete_device_state(self.device_b.id)

    # -------------------------------------------------------------------------
    # 1. CONFIGURATION & CONNECTIVITY TESTS
    # -------------------------------------------------------------------------
    def test_01_redis_configuration_loads(self):
        self.assertTrue(hasattr(settings, 'REDIS_HOST'))
        self.assertTrue(hasattr(settings, 'REDIS_PORT'))
        self.assertTrue(hasattr(settings, 'REDIS_DB'))

    def test_02_redis_ping_succeeds(self):
        self.assertTrue(RedisService.ping())

    # -------------------------------------------------------------------------
    # 2. LOW-LEVEL REDIS SERVICE TESTS (SET, GET, DELETE, TTL, EXPIRATION)
    # -------------------------------------------------------------------------
    def test_03_redis_service_set_and_get(self):
        state = RedisService.set_device_state(self.device_a.id, status="active", battery_level=90, ttl=60)
        self.assertEqual(state['status'], "active")
        self.assertEqual(state['battery_level'], 90)

        retrieved = RedisService.get_device_state(self.device_a.id)
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved['device_id'], self.device_a.id)
        self.assertEqual(retrieved['status'], "active")

    def test_04_redis_service_delete(self):
        RedisService.set_device_state(self.device_a.id, status="active", ttl=60)
        self.assertIsNotNone(RedisService.get_device_state(self.device_a.id))
        
        deleted = RedisService.delete_device_state(self.device_a.id)
        self.assertTrue(deleted)
        self.assertIsNone(RedisService.get_device_state(self.device_a.id))

    def test_05_redis_ttl_behavior(self):
        RedisService.set_device_state(self.device_a.id, status="online", ttl=300)
        ttl = RedisService.get_ttl(self.device_a.id)
        self.assertGreater(ttl, 0)
        self.assertLessEqual(ttl, 300)

    def test_06_redis_ttl_expiration(self):
        RedisService.set_device_state(self.device_a.id, status="transient", ttl=1)
        self.assertIsNotNone(RedisService.get_device_state(self.device_a.id))
        time.sleep(1.1)
        self.assertIsNone(RedisService.get_device_state(self.device_a.id))

    # -------------------------------------------------------------------------
    # 3. API AUTHENTICATION & INPUT VALIDATION TESTS
    # -------------------------------------------------------------------------
    def test_07_unauthenticated_post_rejected(self):
        response = self.unauthenticated_client.post(self.state_url_a, {"status": "online"})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_08_unauthenticated_get_rejected(self):
        response = self.unauthenticated_client.get(self.state_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_09_invalid_battery_rejected(self):
        payload = {"status": "online", "battery_level": 150}
        response = self.client_a.post(self.state_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("battery_level", response.data)

    def test_10_invalid_ttl_rejected(self):
        payload = {"status": "online", "ttl": -10}
        response = self.client_a.post(self.state_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("ttl", response.data)

    # -------------------------------------------------------------------------
    # 4. API FUNCTIONALITY & RETRIEVAL TESTS
    # -------------------------------------------------------------------------
    def test_11_post_state_api_success(self):
        payload = {"status": "online", "battery_level": 85, "ttl": 120}
        response = self.client_a.post(self.state_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['status'], "online")
        self.assertEqual(response.data['battery_level'], 85)

    def test_12_get_state_api_success(self):
        self.client_a.post(self.state_url_a, {"status": "online", "battery_level": 85}, format='json')
        response = self.client_a.get(self.state_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['device_id'], self.device_a.id)
        self.assertEqual(response.data['status'], "online")
        self.assertIn("ttl_remaining", response.data)

    def test_13_get_state_nonexistent_returns_404(self):
        response = self.client_a.get(self.state_url_a)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_14_delete_state_api_success(self):
        self.client_a.post(self.state_url_a, {"status": "online"}, format='json')
        response = self.client_a.delete(self.state_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])

    # -------------------------------------------------------------------------
    # 5. OWNERSHIP & SECURITY TESTS
    # -------------------------------------------------------------------------
    def test_15_user_a_cannot_update_user_b_redis_state(self):
        response = self.client_a.post(self.state_url_b, {"status": "hacked"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIsNone(RedisService.get_device_state(self.device_b.id))

    def test_16_user_a_cannot_view_user_b_redis_state(self):
        self.client_b.post(self.state_url_b, {"status": "online"}, format='json')
        response = self.client_a.get(self.state_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_17_user_b_cannot_update_user_a_redis_state(self):
        response = self.client_b.post(self.state_url_a, {"status": "hacked"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIsNone(RedisService.get_device_state(self.device_a.id))

    def test_18_user_b_cannot_view_user_a_redis_state(self):
        self.client_a.post(self.state_url_a, {"status": "online"}, format='json')
        response = self.client_b.get(self.state_url_a)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_19_nonexistent_device_id_returns_404(self):
        url = reverse('device-state', kwargs={'pk': 99999})
        response = self.client_a.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # 6. POSTGRESQL & PHASE 1-3 INTEGRITY TESTS
    # -------------------------------------------------------------------------
    def test_20_deleting_redis_state_does_not_affect_postgresql_device(self):
        self.client_a.post(self.state_url_a, {"status": "online"}, format='json')
        self.client_a.delete(self.state_url_a)
        self.assertTrue(Device.objects.filter(id=self.device_a.id).exists())

    def test_21_deleting_redis_state_does_not_affect_postgresql_locations(self):
        loc = Location.objects.create(device=self.device_a, latitude=10.0, longitude=20.0, accuracy=5.0)
        self.client_a.post(self.state_url_a, {"status": "online"}, format='json')
        RedisService.delete_device_state(self.device_a.id)
        self.assertTrue(Location.objects.filter(id=loc.id).exists())

    def test_22_jwt_bearer_token_authentication(self):
        refresh = RefreshToken.for_user(self.user_a)
        jwt_client = APIClient()
        jwt_client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        response = jwt_client.post(self.state_url_a, {"status": "online"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)


from django.test import TestCase, TransactionTestCase, override_settings
from django.db import connections

@override_settings(CHANNEL_LAYERS={'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}})
class WebSocketAPITestCase(TransactionTestCase):

    def setUp(self):
        connections.close_all()
        self.user_a = User.objects.create_user(email="ws_user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="ws_user_b@example.com", name="User B", password="password123")

        self.token_a = str(RefreshToken.for_user(self.user_a).access_token)
        self.token_b = str(RefreshToken.for_user(self.user_b).access_token)

        self.device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="ws-id-a")
        self.device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="ws-id-b")

    def tearDown(self):
        RedisService.delete_device_state(self.device_a.id)
        RedisService.delete_device_state(self.device_b.id)
        connections.close_all()

    # -------------------------------------------------------------------------
    # 1. CHANNELS CONFIGURATION & AUTHENTICATION TESTS
    # -------------------------------------------------------------------------
    def test_23_channels_configuration_loads(self):
        self.assertTrue(hasattr(settings, 'ASGI_APPLICATION'))
        self.assertTrue(hasattr(settings, 'CHANNEL_LAYERS'))

    def test_24_asgi_application_loads(self):
        self.assertIsNotNone(application)

    async def test_25_unauthenticated_websocket_connection_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/")
        connected, _ = await communicator.connect()
        self.assertFalse(connected)

    async def test_26_authenticated_websocket_connection_succeeds(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        await communicator.disconnect()

    async def test_27_cross_user_websocket_connection_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_b.id}/?token={self.token_a}")
        connected, _ = await communicator.connect()
        self.assertFalse(connected)

    async def test_28_nonexistent_device_websocket_connection_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/99999/?token={self.token_a}")
        connected, _ = await communicator.connect()
        self.assertFalse(connected)

    # -------------------------------------------------------------------------
    # 2. WEBSOCKET REAL-TIME BROADCAST & PERSISTENCE TESTS
    # -------------------------------------------------------------------------
    async def test_29_valid_location_update_broadcast_and_persisted(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        connected, _ = await communicator.connect()
        self.assertTrue(connected)

        msg = {
            "type": "location_update",
            "device_id": self.device_a.id,
            "latitude": 17.6868,
            "longitude": 83.2185,
            "accuracy": 10.5
        }
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "location_update")
        self.assertEqual(response['latitude'], 17.6868)
        self.assertEqual(response['longitude'], 83.2185)
        self.assertEqual(response['device_id'], self.device_a.id)

        # Verify PostgreSQL persistence asynchronously
        count = await database_sync_to_async(Location.objects.filter(device=self.device_a).count)()
        self.assertEqual(count, 1)

        await communicator.disconnect()

    async def test_30_multiple_clients_same_device_receive_broadcast(self):
        c1 = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        c2 = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")

        self.assertTrue((await c1.connect())[0])
        self.assertTrue((await c2.connect())[0])

        msg = {
            "type": "location_update",
            "device_id": self.device_a.id,
            "latitude": 10.0,
            "longitude": 20.0,
            "accuracy": 5.0
        }
        await c1.send_json_to(msg)

        r1 = await c1.receive_json_from()
        r2 = await c2.receive_json_from()

        self.assertEqual(r1['latitude'], 10.0)
        self.assertEqual(r2['latitude'], 10.0)

        await c1.disconnect()
        await c2.disconnect()

    async def test_31_group_isolation_between_devices(self):
        c_a = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        c_b = WebsocketCommunicator(application, f"/ws/devices/{self.device_b.id}/?token={self.token_b}")

        self.assertTrue((await c_a.connect())[0])
        self.assertTrue((await c_b.connect())[0])

        msg = {
            "type": "location_update",
            "device_id": self.device_a.id,
            "latitude": 10.0,
            "longitude": 20.0,
            "accuracy": 5.0
        }
        await c_a.send_json_to(msg)

        r_a = await c_a.receive_json_from()
        self.assertEqual(r_a['latitude'], 10.0)

        # Client B should NOT receive Client A's message
        self.assertTrue(await c_b.receive_nothing())

        await c_a.disconnect()
        await c_b.disconnect()

    # -------------------------------------------------------------------------
    # 3. INPUT VALIDATION & ERROR HANDLING TESTS
    # -------------------------------------------------------------------------
    async def test_32_malformed_json_rejected_with_error_payload(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        await communicator.send_to(text_data="not-valid-json")
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "MALFORMED_JSON")
        await communicator.disconnect()

    async def test_33_unsupported_message_type_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        await communicator.send_json_to({"type": "unknown_command"})
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "UNSUPPORTED_TYPE")
        await communicator.disconnect()

    async def test_34_device_id_mismatch_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {
            "type": "location_update",
            "device_id": self.device_b.id,
            "latitude": 10.0,
            "longitude": 20.0
        }
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "DEVICE_ID_MISMATCH")
        await communicator.disconnect()

    async def test_35_missing_coordinates_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {"type": "location_update", "latitude": 10.0}
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "MISSING_COORDINATES")
        await communicator.disconnect()

    async def test_36_invalid_latitude_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {"type": "location_update", "latitude": 95.0, "longitude": 20.0}
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "INVALID_LATITUDE")
        await communicator.disconnect()

    async def test_37_invalid_longitude_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {"type": "location_update", "latitude": 10.0, "longitude": 200.0}
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "INVALID_LONGITUDE")
        await communicator.disconnect()

    async def test_38_negative_accuracy_rejected(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {"type": "location_update", "latitude": 10.0, "longitude": 20.0, "accuracy": -5.0}
        await communicator.send_json_to(msg)
        response = await communicator.receive_json_from()

        self.assertEqual(response['type'], "error")
        self.assertEqual(response['code'], "INVALID_ACCURACY")
        await communicator.disconnect()

    async def test_39_disconnect_cleanup(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        await communicator.disconnect()

    async def test_40_redis_state_refreshed_on_websocket_update(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        await communicator.connect()

        msg = {
            "type": "location_update",
            "device_id": self.device_a.id,
            "latitude": 10.0,
            "longitude": 20.0,
            "accuracy": 5.0
        }
        await communicator.send_json_to(msg)
        await communicator.receive_json_from()

        state = await database_sync_to_async(RedisService.get_device_state)(self.device_a.id)
        self.assertIsNotNone(state)
        self.assertEqual(state['status'], "online")
        await communicator.disconnect()
