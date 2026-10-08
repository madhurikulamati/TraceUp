from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken, UntypedToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

User = get_user_model()

@database_sync_to_async
def get_user_from_token(token_key):
    try:
        validated_token = AccessToken(token_key)
        user_id = validated_token.get('user_id') or validated_token.get('id')
        return User.objects.get(id=user_id)
    except (InvalidToken, TokenError, User.DoesNotExist, Exception):
        return AnonymousUser()

class JWTAuthMiddleware:
    """
    Custom Channels ASGI middleware for SimpleJWT WebSocket authentication.
    Supports JWT tokens supplied via query string `?token=<access_token>`
    or `Authorization` header (`Bearer <access_token>`).
    """
    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        token_key = None

        # 1. Try Query String: ?token=<access_token>
        query_string = scope.get('query_string', b'').decode('utf-8')
        query_params = parse_qs(query_string)
        if 'token' in query_params:
            token_key = query_params['token'][0]

        # 2. Try Headers if query param not present
        if not token_key and 'headers' in scope:
            headers = dict(scope.get('headers', []))
            if b'authorization' in headers:
                try:
                    auth_header = headers[b'authorization'].decode('utf-8')
                    if auth_header.startswith('Bearer '):
                        token_key = auth_header.split('Bearer ')[1].strip()
                except Exception:
                    pass

        if token_key:
            scope['user'] = await get_user_from_token(token_key)
        else:
            scope['user'] = AnonymousUser()

        return await self.inner(scope, receive, send)

def JWTAuthMiddlewareStack(inner):
    return JWTAuthMiddleware(inner)
