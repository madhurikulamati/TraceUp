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
        # Clean up Redis keys created during test run
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
