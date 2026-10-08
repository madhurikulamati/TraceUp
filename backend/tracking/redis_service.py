import json
import logging
from django.conf import settings
from django.utils import timezone
import redis

logger = logging.getLogger(__name__)

class RedisService:
    _client = None

    @classmethod
    def get_client(cls, force_reconnect=False):
        if cls._client is not None and not force_reconnect:
            return cls._client

        redis_host = getattr(settings, 'REDIS_HOST', '127.0.0.1')
        redis_port = getattr(settings, 'REDIS_PORT', 6379)
        redis_db = getattr(settings, 'REDIS_DB', 0)
        redis_pass = getattr(settings, 'REDIS_PASSWORD', None)
        use_fake = getattr(settings, 'USE_FAKE_REDIS', False)

        if use_fake:
            import fakeredis
            cls._client = fakeredis.FakeRedis(decode_responses=True)
            return cls._client

        try:
            client = redis.Redis(
                host=redis_host,
                port=redis_port,
                db=redis_db,
                password=redis_pass,
                decode_responses=True,
                socket_timeout=1
            )
            if client.ping():
                cls._client = client
                return cls._client
        except Exception as e:
            logger.warning(f"Could not connect to Redis at {redis_host}:{redis_port}: {e}. Falling back to FakeRedis.")

        import fakeredis
        cls._client = fakeredis.FakeRedis(decode_responses=True)
        return cls._client

    @classmethod
    def ping(cls):
        try:
            return cls.get_client().ping()
        except Exception:
            return False

    @classmethod
    def set_device_state(cls, device_id, status="online", battery_level=None, ttl=300):
        client = cls.get_client()
        key = f"traceup:device:{device_id}:state"
        payload = {
            "device_id": device_id,
            "status": status,
            "last_activity": timezone.now().isoformat(),
            "battery_level": battery_level,
        }
        client.set(key, json.dumps(payload), ex=ttl)
        return payload

    @classmethod
    def get_device_state(cls, device_id):
        client = cls.get_client()
        key = f"traceup:device:{device_id}:state"
        val = client.get(key)
        if val:
            try:
                return json.loads(val)
            except Exception:
                return None
        return None

    @classmethod
    def delete_device_state(cls, device_id):
        client = cls.get_client()
        key = f"traceup:device:{device_id}:state"
        return client.delete(key)

    @classmethod
    def get_ttl(cls, device_id):
        client = cls.get_client()
        key = f"traceup:device:{device_id}:state"
        return client.ttl(key)
