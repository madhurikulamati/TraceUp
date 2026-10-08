from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from devices.models import Device

User = get_user_model()

class DeviceAPITestCase(TestCase):
    def setUp(self):
        self.unauthenticated_client = APIClient()
        self.client_a = APIClient()
        self.client_b = APIClient()

        self.user_a = User.objects.create_user(email="user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="user_b@example.com", name="User B", password="password123")

        self.client_a.force_authenticate(user=self.user_a)
        self.client_b.force_authenticate(user=self.user_b)

        self.devices_url = reverse('device-list-create')

    # -------------------------------------------------------------------------
    # TEST GROUP A — AUTHENTICATION
    # -------------------------------------------------------------------------
    def test_unauthenticated_get_list_rejected(self):
        response = self.unauthenticated_client.get(self.devices_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_post_create_rejected(self):
        data = {
            "name": "Unauthorized Phone",
            "device_type": "android",
            "device_identifier": "unauth-001"
        }
        response = self.unauthenticated_client.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_get_detail_rejected(self):
        device = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        detail_url = reverse('device-detail', kwargs={'pk': device.id})
        response = self.unauthenticated_client.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_delete_rejected(self):
        device = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        detail_url = reverse('device-detail', kwargs={'pk': device.id})
        response = self.unauthenticated_client.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    # -------------------------------------------------------------------------
    # TEST GROUP B — CREATE DEVICE & VALIDATION
    # -------------------------------------------------------------------------
    def test_create_device_success(self):
        data = {
            "name": "Pixel 8 Pro",
            "device_type": "android",
            "device_identifier": "device-uuid-a1",
            "is_online": False,
            "battery_level": 85
        }
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], "Pixel 8 Pro")
        self.assertEqual(response.data['user'], self.user_a.id)

    def test_create_device_stored_in_db(self):
        data = {
            "name": "Galaxy S24",
            "device_type": "android",
            "device_identifier": "galaxy-s24-001"
        }
        self.client_a.post(self.devices_url, data, format='json')
        device = Device.objects.filter(device_identifier="galaxy-s24-001").first()
        self.assertIsNotNone(device)
        self.assertEqual(device.user, self.user_a)

    def test_client_cannot_assign_device_to_another_user(self):
        data = {
            "name": "Hacked Device",
            "device_type": "android",
            "device_identifier": "hacked-001",
            "user": self.user_b.id
        }
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['user'], self.user_a.id)
        device = Device.objects.get(device_identifier="hacked-001")
        self.assertEqual(device.user, self.user_a)

    def test_validation_blank_name(self):
        data = {"name": "   ", "device_type": "android", "device_identifier": "id-blank-name"}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("name", response.data)

    def test_validation_blank_device_type(self):
        data = {"name": "Test Device", "device_type": "", "device_identifier": "id-blank-type"}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("device_type", response.data)

    def test_validation_blank_device_identifier(self):
        data = {"name": "Test Device", "device_type": "android", "device_identifier": "   "}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("device_identifier", response.data)

    def test_battery_level_zero_accepted(self):
        data = {"name": "Zero Battery Phone", "device_type": "android", "device_identifier": "id-bat-0", "battery_level": 0}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['battery_level'], 0)

    def test_battery_level_hundred_accepted(self):
        data = {"name": "Full Battery Phone", "device_type": "android", "device_identifier": "id-bat-100", "battery_level": 100}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['battery_level'], 100)

    def test_battery_level_below_zero_rejected(self):
        data = {"name": "Invalid Battery Phone", "device_type": "android", "device_identifier": "id-bat-neg", "battery_level": -1}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("battery_level", response.data)

    def test_battery_level_above_hundred_rejected(self):
        data = {"name": "Invalid Battery Phone", "device_type": "android", "device_identifier": "id-bat-over", "battery_level": 101}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("battery_level", response.data)

    def test_invalid_battery_does_not_create_db_record(self):
        count_before = Device.objects.count()
        data = {"name": "Invalid Battery Phone", "device_type": "android", "device_identifier": "id-no-db", "battery_level": 150}
        self.client_a.post(self.devices_url, data, format='json')
        count_after = Device.objects.count()
        self.assertEqual(count_before, count_after)

    def test_timestamps_and_defaults(self):
        data = {"name": "Default Specs Device", "device_type": "android", "device_identifier": "id-defaults"}
        response = self.client_a.post(self.devices_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIsNotNone(response.data['created_at'])
        self.assertIsNotNone(response.data['updated_at'])
        self.assertIsNone(response.data['last_seen'])
        self.assertFalse(response.data['is_online'])

    # -------------------------------------------------------------------------
    # TEST GROUP C — LIST DEVICES
    # -------------------------------------------------------------------------
    def test_list_devices_returns_only_own_devices(self):
        Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")

        response = self.client_a.get(self.devices_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['name'], "User A Phone")

    def test_list_devices_empty(self):
        response = self.client_a.get(self.devices_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])

    # -------------------------------------------------------------------------
    # TEST GROUP D — DETAIL
    # -------------------------------------------------------------------------
    def test_get_detail_own_device(self):
        device = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        detail_url = reverse('device-detail', kwargs={'pk': device.id})
        response = self.client_a.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], device.id)
        self.assertEqual(response.data['name'], "User A Phone")

    def test_get_detail_other_user_device_returns_404(self):
        device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")
        detail_url = reverse('device-detail', kwargs={'pk': device_b.id})
        response = self.client_a.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_get_detail_nonexistent_device_returns_404(self):
        detail_url = reverse('device-detail', kwargs={'pk': 99999})
        response = self.client_a.get(detail_url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # TEST GROUP E — DELETE
    # -------------------------------------------------------------------------
    def test_delete_own_device(self):
        device = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        detail_url = reverse('device-detail', kwargs={'pk': device.id})
        response = self.client_a.delete(detail_url)
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_204_NO_CONTENT])
        self.assertFalse(Device.objects.filter(id=device.id).exists())

    def test_delete_other_user_device_returns_404(self):
        device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")
        detail_url = reverse('device-detail', kwargs={'pk': device_b.id})
        response = self.client_a.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Device.objects.filter(id=device_b.id).exists())

    def test_delete_nonexistent_device_returns_404(self):
        detail_url = reverse('device-detail', kwargs={'pk': 99999})
        response = self.client_a.delete(detail_url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # TEST GROUP F — OWNERSHIP SECURITY WORKFLOW
    # -------------------------------------------------------------------------
    def test_cross_user_security_complete_workflow(self):
        device_a = Device.objects.create(user=self.user_a, name="Device A", device_identifier="id-a-workflow")
        device_b = Device.objects.create(user=self.user_b, name="Device B", device_identifier="id-b-workflow")

        url_a = reverse('device-detail', kwargs={'pk': device_a.id})
        url_b = reverse('device-detail', kwargs={'pk': device_b.id})

        # User A list -> only Device A
        res_list_a = self.client_a.get(self.devices_url)
        self.assertEqual(len(res_list_a.data), 1)
        self.assertEqual(res_list_a.data[0]['id'], device_a.id)

        # User B list -> only Device B
        res_list_b = self.client_b.get(self.devices_url)
        self.assertEqual(len(res_list_b.data), 1)
        self.assertEqual(res_list_b.data[0]['id'], device_b.id)

        # User A detail Device A -> 200 OK
        self.assertEqual(self.client_a.get(url_a).status_code, status.HTTP_200_OK)

        # User B detail Device B -> 200 OK
        self.assertEqual(self.client_b.get(url_b).status_code, status.HTTP_200_OK)

        # User A detail Device B -> 404
        self.assertEqual(self.client_a.get(url_b).status_code, status.HTTP_404_NOT_FOUND)

        # User B detail Device A -> 404
        self.assertEqual(self.client_b.get(url_a).status_code, status.HTTP_404_NOT_FOUND)

        # User A delete Device B -> 404
        self.assertEqual(self.client_a.delete(url_b).status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Device.objects.filter(id=device_b.id).exists())

        # User B delete Device A -> 404
        self.assertEqual(self.client_b.delete(url_a).status_code, status.HTTP_404_NOT_FOUND)
        self.assertTrue(Device.objects.filter(id=device_a.id).exists())

        # User A delete Device A -> success
        self.assertIn(self.client_a.delete(url_a).status_code, [status.HTTP_200_OK, status.HTTP_204_NO_CONTENT])
        self.assertFalse(Device.objects.filter(id=device_a.id).exists())

        # User B delete Device B -> success
        self.assertIn(self.client_b.delete(url_b).status_code, [status.HTTP_200_OK, status.HTTP_204_NO_CONTENT])
        self.assertFalse(Device.objects.filter(id=device_b.id).exists())

    # -------------------------------------------------------------------------
    # TEST GROUP G — JWT BEARER TOKEN AUTHENTICATION
    # -------------------------------------------------------------------------
    def test_jwt_bearer_token_authentication(self):
        refresh = RefreshToken.for_user(self.user_a)
        jwt_client = APIClient()
        jwt_client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        response = jwt_client.get(self.devices_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)


from django.test import TransactionTestCase, override_settings
from channels.testing import WebsocketCommunicator
from channels.db import database_sync_to_async
from config.asgi import application

@override_settings(CHANNEL_LAYERS={'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}})
class RingAndLostModeAPITestCase(TransactionTestCase):

    def setUp(self):
        self.unauthenticated_client = APIClient()
        self.client_a = APIClient()
        self.client_b = APIClient()

        self.user_a = User.objects.create_user(email="ring_user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="ring_user_b@example.com", name="User B", password="password123")

        self.client_a.force_authenticate(user=self.user_a)
        self.client_b.force_authenticate(user=self.user_b)

        self.token_a = str(RefreshToken.for_user(self.user_a).access_token)
        self.token_b = str(RefreshToken.for_user(self.user_b).access_token)

        self.device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="ring-id-a")
        self.device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="ring-id-b")

        self.ring_url_a = reverse('device-ring', kwargs={'pk': self.device_a.id})
        self.ring_url_b = reverse('device-ring', kwargs={'pk': self.device_b.id})

        self.lost_mode_url_a = reverse('device-lost-mode', kwargs={'pk': self.device_a.id})
        self.lost_mode_url_b = reverse('device-lost-mode', kwargs={'pk': self.device_b.id})

    # -------------------------------------------------------------------------
    # 1. RING REST API TESTS
    # -------------------------------------------------------------------------
    def test_unauthenticated_ring_rejected(self):
        response = self.unauthenticated_client.post(self.ring_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_owner_ring_success(self):
        response = self.client_a.post(self.ring_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['device_id'], self.device_a.id)

    def test_cross_user_ring_rejected(self):
        response = self.client_a.post(self.ring_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_nonexistent_device_ring_rejected(self):
        url = reverse('device-ring', kwargs={'pk': 99999})
        response = self.client_a.post(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # 2. LOST MODE REST API TESTS
    # -------------------------------------------------------------------------
    def test_unauthenticated_lost_mode_enable_rejected(self):
        response = self.unauthenticated_client.post(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_lost_mode_disable_rejected(self):
        response = self.unauthenticated_client.delete(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_lost_mode_status_rejected(self):
        response = self.unauthenticated_client.get(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_owner_enable_lost_mode_success(self):
        response = self.client_a.post(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertTrue(response.data['is_lost_mode'])

        self.device_a.refresh_from_db()
        self.assertTrue(self.device_a.is_lost_mode)
        self.assertIsNotNone(self.device_a.lost_mode_enabled_at)

    def test_owner_get_lost_mode_status(self):
        self.client_a.post(self.lost_mode_url_a)
        response = self.client_a.get(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_lost_mode'])
        self.assertEqual(response.data['device_id'], self.device_a.id)

    def test_owner_disable_lost_mode_success(self):
        self.client_a.post(self.lost_mode_url_a)
        response = self.client_a.delete(self.lost_mode_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_lost_mode'])

        self.device_a.refresh_from_db()
        self.assertFalse(self.device_a.is_lost_mode)

    def test_enable_lost_mode_idempotent(self):
        r1 = self.client_a.post(self.lost_mode_url_a)
        t1 = r1.data['lost_mode_enabled_at']
        r2 = self.client_a.post(self.lost_mode_url_a)
        t2 = r2.data['lost_mode_enabled_at']
        self.assertEqual(t1, t2)

    def test_cross_user_enable_lost_mode_rejected(self):
        response = self.client_a.post(self.lost_mode_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_cross_user_disable_lost_mode_rejected(self):
        response = self.client_a.delete(self.lost_mode_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_cross_user_get_lost_mode_status_rejected(self):
        response = self.client_a.get(self.lost_mode_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_nonexistent_device_lost_mode_rejected(self):
        url = reverse('device-lost-mode', kwargs={'pk': 99999})
        response = self.client_a.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # 3. WEBSOCKET REAL-TIME DELIVERIES
    # -------------------------------------------------------------------------
    async def test_websocket_ring_command_delivered_to_target_device(self):
        communicator_a = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        communicator_b = WebsocketCommunicator(application, f"/ws/devices/{self.device_b.id}/?token={self.token_b}")

        self.assertTrue((await communicator_a.connect())[0])
        self.assertTrue((await communicator_b.connect())[0])

        # Trigger REST API ring for Device A asynchronously
        await database_sync_to_async(self.client_a.post)(self.ring_url_a)

        response_a = await communicator_a.receive_json_from()
        self.assertEqual(response_a['type'], "ring_command")
        self.assertEqual(response_a['device_id'], self.device_a.id)

        # Device B should receive nothing
        self.assertTrue(await communicator_b.receive_nothing())

        await communicator_a.disconnect()
        await communicator_b.disconnect()

    async def test_websocket_lost_mode_enable_broadcast_delivered(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        self.assertTrue((await communicator.connect())[0])

        await database_sync_to_async(self.client_a.post)(self.lost_mode_url_a)

        response = await communicator.receive_json_from()
        self.assertEqual(response['type'], "lost_mode_update")
        self.assertEqual(response['device_id'], self.device_a.id)
        self.assertTrue(response['is_lost_mode'])

        await communicator.disconnect()

    async def test_websocket_lost_mode_disable_broadcast_delivered(self):
        communicator = WebsocketCommunicator(application, f"/ws/devices/{self.device_a.id}/?token={self.token_a}")
        self.assertTrue((await communicator.connect())[0])

        await database_sync_to_async(self.client_a.delete)(self.lost_mode_url_a)

        response = await communicator.receive_json_from()
        self.assertEqual(response['type'], "lost_mode_update")
        self.assertEqual(response['device_id'], self.device_a.id)
        self.assertFalse(response['is_lost_mode'])

        await communicator.disconnect()

