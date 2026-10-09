from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken

from devices.models import Device
from notifications.models import FCMToken
from notifications.firebase_service import initialize_firebase, send_fcm_notification

User = get_user_model()

class FCMNotificationAPITestCase(TestCase):
    def setUp(self):
        self.unauthenticated_client = APIClient()
        self.client_a = APIClient()
        self.client_b = APIClient()

        self.user_a = User.objects.create_user(email="fcm_user_a@example.com", name="User A", password="password123")
        self.user_b = User.objects.create_user(email="fcm_user_b@example.com", name="User B", password="password123")

        self.client_a.force_authenticate(user=self.user_a)
        self.client_b.force_authenticate(user=self.user_b)

        self.device_a = Device.objects.create(user=self.user_a, name="User A Phone", device_identifier="fcm-dev-a")
        self.device_b = Device.objects.create(user=self.user_b, name="User B Phone", device_identifier="fcm-dev-b")

        self.token_url_a = reverse('device-fcm-token', kwargs={'pk': self.device_a.id})
        self.token_url_b = reverse('device-fcm-token', kwargs={'pk': self.device_b.id})

        self.test_url_a = reverse('device-fcm-test', kwargs={'pk': self.device_a.id})
        self.test_url_b = reverse('device-fcm-test', kwargs={'pk': self.device_b.id})

    # -------------------------------------------------------------------------
    # 1. FCM TOKEN REGISTRATION TESTS (POST /api/devices/{id}/fcm-token/)
    # -------------------------------------------------------------------------
    def test_unauthenticated_token_registration_rejected(self):
        response = self.unauthenticated_client.post(self.token_url_a, {"token": "sample-token-123"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_owner_register_token_success(self):
        data = {"token": "fcm-token-user-a-device-1"}
        response = self.client_a.post(self.token_url_a, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['data']['token'], "fcm-token-user-a-device-1")

        db_token = FCMToken.objects.filter(device=self.device_a, token="fcm-token-user-a-device-1").first()
        self.assertIsNotNone(db_token)
        self.assertTrue(db_token.is_active)
        self.assertEqual(db_token.user, self.user_a)

    def test_cross_user_token_registration_rejected(self):
        data = {"token": "malicious-token"}
        response = self.client_a.post(self.token_url_b, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertFalse(FCMToken.objects.filter(token="malicious-token").exists())

    def test_nonexistent_device_token_registration_rejected(self):
        url = reverse('device-fcm-token', kwargs={'pk': 99999})
        response = self.client_a.post(url, {"token": "some-token"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_register_missing_or_blank_token_rejected(self):
        res1 = self.client_a.post(self.token_url_a, {}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_400_BAD_REQUEST)

        res2 = self.client_a.post(self.token_url_a, {"token": "   "}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)

    def test_token_update_replaces_or_activates_existing(self):
        token_str = "reusable-fcm-token-xyz"
        # Register first time
        res1 = self.client_a.post(self.token_url_a, {"token": token_str}, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Deactivate
        self.client_a.delete(self.token_url_a, {"token": token_str}, format='json')
        token_obj = FCMToken.objects.get(token=token_str)
        self.assertFalse(token_obj.is_active)

        # Register again -> updates to active
        res2 = self.client_a.post(self.token_url_a, {"token": token_str}, format='json')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        token_obj.refresh_from_db()
        self.assertTrue(token_obj.is_active)

    # -------------------------------------------------------------------------
    # 2. FCM TOKEN UNREGISTER TESTS (DELETE /api/devices/{id}/fcm-token/)
    # -------------------------------------------------------------------------
    def test_unauthenticated_token_unregister_rejected(self):
        response = self.unauthenticated_client.delete(self.token_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_owner_unregister_token_success(self):
        FCMToken.objects.create(user=self.user_a, device=self.device_a, token="token-to-delete", is_active=True)
        response = self.client_a.delete(self.token_url_a, {"token": "token-to-delete"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertEqual(response.data['deactivated_count'], 1)

        token_obj = FCMToken.objects.get(token="token-to-delete")
        self.assertFalse(token_obj.is_active)

    def test_owner_unregister_all_tokens_when_no_token_body(self):
        FCMToken.objects.create(user=self.user_a, device=self.device_a, token="t1", is_active=True)
        FCMToken.objects.create(user=self.user_a, device=self.device_a, token="t2", is_active=True)

        response = self.client_a.delete(self.token_url_a)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['deactivated_count'], 2)
        self.assertEqual(FCMToken.objects.filter(device=self.device_a, is_active=True).count(), 0)

    def test_cross_user_token_unregister_rejected(self):
        FCMToken.objects.create(user=self.user_b, device=self.device_b, token="user-b-token", is_active=True)
        response = self.client_a.delete(self.token_url_b, {"token": "user-b-token"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

        token_obj = FCMToken.objects.get(token="user-b-token")
        self.assertTrue(token_obj.is_active)

    # -------------------------------------------------------------------------
    # 3. MOCKED FIREBASE SERVICE & TEST NOTIFICATION ENDPOINT
    # -------------------------------------------------------------------------
    @patch('notifications.firebase_service.initialize_firebase', return_value=True)
    @patch('firebase_admin.messaging.send', return_value='projects/test-project/messages/msg-123')
    def test_fcm_test_notification_api_success(self, mock_send, mock_init):
        FCMToken.objects.create(user=self.user_a, device=self.device_a, token="valid-fcm-token-123", is_active=True)

        response = self.client_a.post(self.test_url_a, {"title": "Custom Test", "body": "Testing FCM"}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['success'])
        self.assertTrue(mock_send.called)

    def test_fcm_test_notification_no_token_returns_400(self):
        response = self.client_a.post(self.test_url_a, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.data['success'])
        self.assertEqual(response.data['error'], "No active FCM token registered for this device.")

    def test_fcm_test_notification_unauthenticated_rejected(self):
        response = self.unauthenticated_client.post(self.test_url_a)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_fcm_test_notification_cross_user_rejected(self):
        response = self.client_a.post(self.test_url_b)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    @patch('notifications.firebase_service.initialize_firebase', return_value=True)
    def test_unregistered_token_deactivation_during_send(self, mock_init):
        from firebase_admin import messaging
        token_obj = FCMToken.objects.create(user=self.user_a, device=self.device_a, token="expired-token", is_active=True)

        with patch('firebase_admin.messaging.send', side_effect=messaging.UnregisteredError("App instance has been unregistered")):
            result = send_fcm_notification(self.device_a, "Test", "Message")
            self.assertFalse(result['success'])
            self.assertIn(token_obj.id, result['deactivated_tokens'])

            token_obj.refresh_from_db()
            self.assertFalse(token_obj.is_active)

    # -------------------------------------------------------------------------
    # 4. RING & LOST MODE INTEGRATION WITH FCM
    # -------------------------------------------------------------------------
    @patch('notifications.firebase_service.send_fcm_notification')
    def test_ring_api_triggers_fcm_notification(self, mock_send_fcm):
        ring_url = reverse('device-ring', kwargs={'pk': self.device_a.id})
        response = self.client_a.post(ring_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(mock_send_fcm.called)
        
        args, kwargs = mock_send_fcm.call_args
        self.assertEqual(kwargs['device'], self.device_a)
        self.assertEqual(kwargs['data']['type'], 'ring')

    @patch('notifications.firebase_service.send_fcm_notification')
    def test_lost_mode_enable_triggers_fcm_notification(self, mock_send_fcm):
        lost_url = reverse('device-lost-mode', kwargs={'pk': self.device_a.id})
        response = self.client_a.post(lost_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(mock_send_fcm.called)

        args, kwargs = mock_send_fcm.call_args
        self.assertEqual(kwargs['device'], self.device_a)
        self.assertEqual(kwargs['data']['type'], 'lost_mode_enabled')

    @patch('notifications.firebase_service.send_fcm_notification')
    def test_lost_mode_disable_triggers_fcm_notification(self, mock_send_fcm):
        lost_url = reverse('device-lost-mode', kwargs={'pk': self.device_a.id})
        response = self.client_a.delete(lost_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(mock_send_fcm.called)

        args, kwargs = mock_send_fcm.call_args
        self.assertEqual(kwargs['device'], self.device_a)
        self.assertEqual(kwargs['data']['type'], 'lost_mode_disabled')
