import os
import logging
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_SDK_AVAILABLE = True
except ImportError:
    FIREBASE_SDK_AVAILABLE = False
    logger.warning("firebase_admin package is not installed.")

_firebase_app_initialized = False

def initialize_firebase():
    """
    Safely initialize the Firebase Admin SDK once using server-side service account credentials.
    Returns True if initialized successfully or already initialized, False otherwise.
    """
    global _firebase_app_initialized

    if not FIREBASE_SDK_AVAILABLE:
        logger.warning("Firebase Admin SDK is not available.")
        return False

    # Return True if already initialized in firebase_admin apps
    if firebase_admin._apps:
        _firebase_app_initialized = True
        return True

    cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
    if not cred_path:
        cred_path = os.environ.get('FIREBASE_CREDENTIALS_PATH', None)

    if not cred_path:
        logger.info("FIREBASE_CREDENTIALS_PATH environment variable is not set.")
        return False

    resolved_path = os.path.abspath(cred_path) if not os.isabs(cred_path) else cred_path

    if not os.path.exists(resolved_path):
        logger.warning(f"Firebase credentials file not found at: {resolved_path}")
        return False

    try:
        cred = credentials.Certificate(resolved_path)
        firebase_admin.initialize_app(cred)
        _firebase_app_initialized = True
        logger.info("Firebase Admin SDK initialized successfully.")
        return True
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        return False


def send_fcm_notification(device, title, body, data=None):
    """
    Sends a Firebase Cloud Messaging push notification to all active tokens for a given device.
    
    Args:
        device: Device instance
        title (str): Notification title
        body (str): Notification body text
        data (dict, optional): Additional key-value payload (all values converted to strings)

    Returns:
        dict: Delivery result summary containing success status, sent count, failed count, deactivated tokens.
    """
    from .models import FCMToken

    active_tokens = FCMToken.objects.filter(device=device, is_active=True)
    if not active_tokens.exists():
        return {
            "success": False,
            "sent_count": 0,
            "failed_count": 0,
            "error": "No active FCM token registered for this device.",
            "deactivated_tokens": []
        }

    is_initialized = initialize_firebase()
    if not is_initialized:
        return {
            "success": False,
            "sent_count": 0,
            "failed_count": active_tokens.count(),
            "error": "Firebase Admin SDK is not configured or failed to initialize.",
            "deactivated_tokens": []
        }

    # Format data payload dictionary — FCM requires all data values to be strings
    formatted_data = {}
    if data:
        for k, v in data.items():
            formatted_data[str(k)] = str(v)

    sent_count = 0
    failed_count = 0
    deactivated_tokens = []
    errors = []

    for token_record in active_tokens:
        try:
            notification = messaging.Notification(title=title, body=body)
            message = messaging.Message(
                notification=notification,
                data=formatted_data,
                token=token_record.token
            )
            response = messaging.send(message)
            sent_count += 1
            token_record.last_used_at = timezone.now()
            token_record.save(update_fields=['last_used_at', 'updated_at'])
            logger.info(f"FCM notification sent successfully to token {token_record.id}. Response: {response}")
        except messaging.UnregisteredError:
            token_record.is_active = False
            token_record.save(update_fields=['is_active', 'updated_at'])
            deactivated_tokens.append(token_record.id)
            failed_count += 1
            logger.info(f"FCM token {token_record.id} is unregistered; deactivated.")
        except messaging.InvalidArgumentError as e:
            token_record.is_active = False
            token_record.save(update_fields=['is_active', 'updated_at'])
            deactivated_tokens.append(token_record.id)
            failed_count += 1
            logger.warning(f"FCM token {token_record.id} has invalid argument: {e}; deactivated.")
        except Exception as e:
            failed_count += 1
            err_str = str(e)
            errors.append(err_str)
            logger.error(f"FCM notification delivery error for token {token_record.id}: {err_str}")

            # Deactivate if error message explicitly indicates invalid/unregistered token
            if any(term in err_str.lower() for term in ["unregistered", "invalid-registration-token", "registration-token-not-registered"]):
                token_record.is_active = False
                token_record.save(update_fields=['is_active', 'updated_at'])
                deactivated_tokens.append(token_record.id)

    overall_success = sent_count > 0

    return {
        "success": overall_success,
        "sent_count": sent_count,
        "failed_count": failed_count,
        "deactivated_tokens": deactivated_tokens,
        "errors": errors
    }
