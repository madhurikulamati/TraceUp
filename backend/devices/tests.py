from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from devices.models import Device
from locations.models import Location

User = get_user_model()

class DeviceAndLocationAPITestCase(TestCase):
    def setUp(self):
        self.client_a = APIClient()
        self.client_b = APIClient()

        self.user_a = User.objects.create_user(email="user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="user_b@example.com", name="User B", password="password123")

        self.client_a.force_authenticate(user=self.user_a)
        self.client_b.force_authenticate(user=self.user_b)

        self.device_url = reverse('device-list-create')

    def test_create_device(self):
        data = {
            "name": "Pixel 8 Pro",
            "device_type": "android",
            "device_identifier": "device-uuid-a1"
        }
        response = self.client_a.post(self.device_url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], "Pixel 8 Pro")
        self.assertEqual(response.data['user'], self.user_a.id)

    def test_list_devices_only_returns_own_devices(self):
        Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")

        response_a = self.client_a.get(self.device_url)
        self.assertEqual(response_a.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_a.data), 1)
        self.assertEqual(response_a.data[0]['name'], "User A Phone")

    def test_cross_user_device_access_denied(self):
        device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="id-b")
        detail_url = reverse('device-detail', kwargs={'pk': device_b.id})

        response_a = self.client_a.get(detail_url)
        self.assertEqual(response_a.status_code, status.HTTP_404_NOT_FOUND)

        delete_response = self.client_a.delete(detail_url)
        self.assertEqual(delete_response.status_code, status.HTTP_404_NOT_FOUND)

    def test_post_and_get_location(self):
        device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        loc_url = reverse('device-location', kwargs={'pk': device_a.id})

        loc_data = {
            "latitude": 16.2356,
            "longitude": 80.0498,
            "accuracy": 10.5
        }
        response = self.client_a.post(loc_url, loc_data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data['success'])

        device_a.refresh_from_db()
        self.assertTrue(device_a.is_online)
        self.assertIsNotNone(device_a.last_seen)

        # GET latest location
        get_loc_response = self.client_a.get(loc_url)
        self.assertEqual(get_loc_response.status_code, status.HTTP_200_OK)
        self.assertEqual(get_loc_response.data['latitude'], 16.2356)

    def test_location_history(self):
        device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        Location.objects.create(device=device_a, latitude=10.0, longitude=20.0, accuracy=5.0)
        Location.objects.create(device=device_a, latitude=10.1, longitude=20.1, accuracy=5.0)

        history_url = reverse('device-location-history', kwargs={'pk': device_a.id})
        response = self.client_a.get(history_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Check paginated or direct list response
        results = response.data['results'] if 'results' in response.data else response.data
        self.assertEqual(len(results), 2)

    def test_ring_and_lost_mode(self):
        device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="id-a")
        ring_url = reverse('device-ring', kwargs={'pk': device_a.id})
        lost_url = reverse('device-lost-mode', kwargs={'pk': device_a.id})

        resp_ring = self.client_a.post(ring_url)
        self.assertEqual(resp_ring.status_code, status.HTTP_200_OK)
        self.assertTrue(resp_ring.data['success'])

        resp_lost = self.client_a.post(lost_url)
        self.assertEqual(resp_lost.status_code, status.HTTP_200_OK)
        self.assertTrue(resp_lost.data['success'])
