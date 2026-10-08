from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from devices.models import Device
from locations.models import Location
import time

User = get_user_model()

class LocationAPITestCase(TestCase):
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

        self.loc_url_a = reverse('device-location', kwargs={'pk': self.device_a.id})
        self.loc_url_b = reverse('device-location', kwargs={'pk': self.device_b.id})
        self.history_url_a = reverse('device-location-history', kwargs={'pk': self.device_a.id})
        self.history_url_b = reverse('device-location-history', kwargs={'pk': self.device_b.id})

    # -------------------------------------------------------------------------
    # AUTHENTICATION TESTS (1 - 3)
    # -------------------------------------------------------------------------
    def test_01_unauthenticated_post_location_rejected(self):
        response = self.unauthenticated_client.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_02_unauthenticated_get_location_rejected(self):
        response = self.unauthenticated_client.get(self.loc_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_03_unauthenticated_get_locations_history_rejected(self):
        response = self.unauthenticated_client.get(self.history_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    # -------------------------------------------------------------------------
    # CREATE LOCATION TESTS (4 - 10)
    # -------------------------------------------------------------------------
    def test_04_create_location_success(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_05_create_location_returns_201_created(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_06_create_location_persisted(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(Location.objects.filter(device=self.device_a).count(), 1)

    def test_07_location_belongs_to_correct_device(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        self.client_a.post(self.loc_url_a, payload, format='json')
        loc = Location.objects.filter(device=self.device_a).first()
        self.assertEqual(loc.device, self.device_a)

    def test_08_device_belongs_to_authenticated_user(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        self.client_a.post(self.loc_url_a, payload, format='json')
        loc = Location.objects.filter(device=self.device_a).first()
        self.assertEqual(loc.device.user, self.user_a)

    def test_09_response_contains_correct_location_data(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.data['latitude'], 17.6868)
        self.assertEqual(response.data['longitude'], 83.2185)
        self.assertEqual(response.data['accuracy'], 10.5)

    def test_10_timestamp_generated_correctly(self):
        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertIsNotNone(response.data.get('timestamp'))

    # -------------------------------------------------------------------------
    # LATITUDE TESTS (11 - 18)
    # -------------------------------------------------------------------------
    def test_11_latitude_90_accepted(self):
        payload = {"latitude": 90.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_12_latitude_minus_90_accepted(self):
        payload = {"latitude": -90.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_13_latitude_0_accepted(self):
        payload = {"latitude": 0.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_14_latitude_above_90_rejected(self):
        payload = {"latitude": 90.000001, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_15_latitude_below_minus_90_rejected(self):
        payload = {"latitude": -90.000001, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_16_latitude_100_rejected(self):
        payload = {"latitude": 100.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_17_latitude_minus_100_rejected(self):
        payload = {"latitude": -100.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_18_no_invalid_location_saved_after_invalid_latitude(self):
        count_before = Location.objects.count()
        payload = {"latitude": 120.0, "longitude": 0.0, "accuracy": 5.0}
        self.client_a.post(self.loc_url_a, payload, format='json')
        count_after = Location.objects.count()
        self.assertEqual(count_before, count_after)

    # -------------------------------------------------------------------------
    # LONGITUDE TESTS (19 - 26)
    # -------------------------------------------------------------------------
    def test_19_longitude_180_accepted(self):
        payload = {"latitude": 0.0, "longitude": 180.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_20_longitude_minus_180_accepted(self):
        payload = {"latitude": 0.0, "longitude": -180.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_21_longitude_0_accepted(self):
        payload = {"latitude": 0.0, "longitude": 0.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_22_longitude_above_180_rejected(self):
        payload = {"latitude": 0.0, "longitude": 180.000001, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_23_longitude_below_minus_180_rejected(self):
        payload = {"latitude": 0.0, "longitude": -180.000001, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_24_longitude_200_rejected(self):
        payload = {"latitude": 0.0, "longitude": 200.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_25_longitude_minus_200_rejected(self):
        payload = {"latitude": 0.0, "longitude": -200.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_26_no_invalid_location_saved_after_invalid_longitude(self):
        count_before = Location.objects.count()
        payload = {"latitude": 0.0, "longitude": 250.0, "accuracy": 5.0}
        self.client_a.post(self.loc_url_a, payload, format='json')
        count_after = Location.objects.count()
        self.assertEqual(count_before, count_after)

    # -------------------------------------------------------------------------
    # ACCURACY TESTS (27 - 30)
    # -------------------------------------------------------------------------
    def test_27_valid_positive_accuracy_accepted(self):
        payload = {"latitude": 10.0, "longitude": 20.0, "accuracy": 15.5}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_28_accuracy_zero_accepted(self):
        payload = {"latitude": 10.0, "longitude": 20.0, "accuracy": 0.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_29_negative_accuracy_rejected(self):
        payload = {"latitude": 10.0, "longitude": 20.0, "accuracy": -5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_30_missing_accuracy_handled(self):
        payload = {"latitude": 10.0, "longitude": 20.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    # -------------------------------------------------------------------------
    # REQUIRED FIELD TESTS (31 - 34)
    # -------------------------------------------------------------------------
    def test_31_missing_latitude_rejected(self):
        payload = {"longitude": 20.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_32_missing_longitude_rejected(self):
        payload = {"latitude": 10.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_33_invalid_null_latitude_rejected(self):
        payload = {"latitude": None, "longitude": 20.0, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_34_invalid_null_longitude_rejected(self):
        payload = {"latitude": 10.0, "longitude": None, "accuracy": 5.0}
        response = self.client_a.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    # -------------------------------------------------------------------------
    # LATEST LOCATION TESTS (35 - 39)
    # -------------------------------------------------------------------------
    def test_35_owner_can_retrieve_latest_location(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        response = self.client_a.get(self.loc_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['latitude'], 10.0)

    def test_36_latest_endpoint_returns_newest_location(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_a.post(self.loc_url_a, {"latitude": 15.0, "longitude": 25.0}, format='json')
        response = self.client_a.get(self.loc_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['latitude'], 15.0)

    def test_37_multiple_location_records_work_correctly(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_a.post(self.loc_url_a, {"latitude": 11.0, "longitude": 21.0}, format='json')
        self.assertEqual(Location.objects.filter(device=self.device_a).count(), 2)

    def test_38_latest_endpoint_does_not_return_older_location(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_a.post(self.loc_url_a, {"latitude": 12.0, "longitude": 22.0}, format='json')
        response = self.client_a.get(self.loc_url_a)
        self.assertNotEqual(response.data['latitude'], 10.0)
        self.assertEqual(response.data['latitude'], 12.0)

    def test_39_device_with_no_location_behaves_correctly(self):
        response = self.client_a.get(self.loc_url_a)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # HISTORY TESTS (40 - 44)
    # -------------------------------------------------------------------------
    def test_40_owner_can_retrieve_location_history(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        response = self.client_a.get(self.history_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_41_multiple_location_records_are_returned(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_a.post(self.loc_url_a, {"latitude": 11.0, "longitude": 21.0}, format='json')
        response = self.client_a.get(self.history_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_42_history_contains_only_locations_for_requested_device(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_b.post(self.loc_url_b, {"latitude": 30.0, "longitude": 40.0}, format='json')
        response = self.client_a.get(self.history_url_a)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['latitude'], 10.0)

    def test_43_history_ordering_is_correct(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.client_a.post(self.loc_url_a, {"latitude": 11.0, "longitude": 21.0}, format='json')
        response = self.client_a.get(self.history_url_a)
        self.assertEqual(response.data[0]['latitude'], 11.0)
        self.assertEqual(response.data[1]['latitude'], 10.0)

    def test_44_locations_from_another_device_do_not_appear(self):
        self.client_b.post(self.loc_url_b, {"latitude": 50.0, "longitude": 60.0}, format='json')
        response = self.client_a.get(self.history_url_a)
        self.assertEqual(response.data, [])

    # -------------------------------------------------------------------------
    # DEVICE STATUS TESTS (45 - 47)
    # -------------------------------------------------------------------------
    def test_45_saving_valid_location_updates_last_seen(self):
        self.assertIsNone(self.device_a.last_seen)
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.device_a.refresh_from_db()
        self.assertIsNotNone(self.device_a.last_seen)

    def test_46_saving_valid_location_updates_is_online(self):
        self.assertFalse(self.device_a.is_online)
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.device_a.refresh_from_db()
        self.assertTrue(self.device_a.is_online)

    def test_47_device_status_update_applies_only_to_target_device(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.device_a.refresh_from_db()
        self.device_b.refresh_from_db()
        self.assertTrue(self.device_a.is_online)
        self.assertFalse(self.device_b.is_online)

    # -------------------------------------------------------------------------
    # OWNERSHIP SECURITY TESTS (48 - 55)
    # -------------------------------------------------------------------------
    def test_48_user_a_cannot_create_location_for_user_b_device(self):
        response = self.client_a.post(self.loc_url_b, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_49_user_a_cannot_retrieve_user_b_latest_location(self):
        self.client_b.post(self.loc_url_b, {"latitude": 30.0, "longitude": 40.0}, format='json')
        response = self.client_a.get(self.loc_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_50_user_a_cannot_retrieve_user_b_location_history(self):
        self.client_b.post(self.loc_url_b, {"latitude": 30.0, "longitude": 40.0}, format='json')
        response = self.client_a.get(self.history_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_51_user_b_cannot_create_location_for_user_a_device(self):
        response = self.client_b.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_52_user_b_cannot_retrieve_user_a_latest_location(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        response = self.client_b.get(self.loc_url_a)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_53_user_b_cannot_retrieve_user_a_location_history(self):
        self.client_a.post(self.loc_url_a, {"latitude": 10.0, "longitude": 20.0}, format='json')
        response = self.client_b.get(self.history_url_a)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_54_failed_cross_user_post_does_not_create_location(self):
        count_before = Location.objects.count()
        self.client_a.post(self.loc_url_b, {"latitude": 10.0, "longitude": 20.0}, format='json')
        count_after = Location.objects.count()
        self.assertEqual(count_before, count_after)

    def test_55_failed_cross_user_get_does_not_leak_location_data(self):
        self.client_b.post(self.loc_url_b, {"latitude": 30.0, "longitude": 40.0}, format='json')
        response = self.client_a.get(self.loc_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertNotIn("30.0", str(response.content))

    # -------------------------------------------------------------------------
    # INVALID DEVICE TESTS (56 - 58)
    # -------------------------------------------------------------------------
    def test_56_nonexistent_device_post_returns_404(self):
        url = reverse('device-location', kwargs={'pk': 99999})
        response = self.client_a.post(url, {"latitude": 10.0, "longitude": 20.0}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_57_nonexistent_device_latest_location_returns_404(self):
        url = reverse('device-location', kwargs={'pk': 99999})
        response = self.client_a.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_58_nonexistent_device_history_returns_404(self):
        url = reverse('device-location-history', kwargs={'pk': 99999})
        response = self.client_a.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    # -------------------------------------------------------------------------
    # DATABASE PERSISTENCE & JWT TESTS (59 - 60)
    # -------------------------------------------------------------------------
    def test_59_location_persisted_in_postgresql(self):
        self.client_a.post(self.loc_url_a, {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}, format='json')
        loc = Location.objects.filter(device=self.device_a).first()
        self.assertIsNotNone(loc)
        self.assertEqual(loc.latitude, 17.6868)
        self.assertEqual(loc.longitude, 83.2185)

    def test_60_jwt_bearer_token_authentication(self):
        refresh = RefreshToken.for_user(self.user_a)
        jwt_client = APIClient()
        jwt_client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

        payload = {"latitude": 17.6868, "longitude": 83.2185, "accuracy": 10.5}
        response = jwt_client.post(self.loc_url_a, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
