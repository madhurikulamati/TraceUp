# TraceUp Find My Device — API Specification Contract

This document forms the binding REST API contract between Backend and Frontend (Flutter/Android).

---

## Base URL
`http://<SERVER_HOST>:<PORT>/api`

---

## 1. Authentication Endpoints

### Register User
- **Method**: `POST`
- **URL**: `/api/auth/register/`
- **Authentication**: None Required
- **Request Body**:
```json
{
  "name": "Rajini",
  "email": "user@example.com",
  "password": "password123"
}
```
- **Response** (201 Created):
```json
{
  "access": "JWT_ACCESS_TOKEN",
  "refresh": "JWT_REFRESH_TOKEN",
  "user": {
    "id": 1,
    "name": "Rajini",
    "email": "user@example.com",
    "created_at": "2026-10-07T10:00:00Z"
  }
}
```

---

### Login User
- **Method**: `POST`
- **URL**: `/api/auth/login/`
- **Authentication**: None Required
- **Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```
- **Response** (200 OK):
```json
{
  "access": "JWT_ACCESS_TOKEN",
  "refresh": "JWT_REFRESH_TOKEN",
  "user": {
    "id": 1,
    "name": "Rajini",
    "email": "user@example.com"
  }
}
```

---

### Get Authenticated User Profile
- **Method**: `GET`
- **URL**: `/api/auth/me/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "id": 1,
  "name": "Rajini",
  "email": "user@example.com",
  "created_at": "2026-10-07T10:00:00Z"
}
```

---

## 2. Device Management Endpoints

### Create Device
- **Method**: `POST`
- **URL**: `/api/devices/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Request Body**:
```json
{
  "name": "Pixel 8 Pro",
  "device_type": "android",
  "device_identifier": "device-uuid-12345"
}
```
- **Response** (201 Created):
```json
{
  "id": 101,
  "user": 1,
  "name": "Pixel 8 Pro",
  "device_type": "android",
  "device_identifier": "device-uuid-12345",
  "is_online": false,
  "battery_level": 100,
  "last_seen": null,
  "created_at": "2026-10-07T10:00:00Z",
  "updated_at": "2026-10-07T10:00:00Z"
}
```

---

### List User's Devices
- **Method**: `GET`
- **URL**: `/api/devices/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
[
  {
    "id": 101,
    "user": 1,
    "name": "Pixel 8 Pro",
    "device_type": "android",
    "device_identifier": "device-uuid-12345",
    "is_online": true,
    "battery_level": 85,
    "last_seen": "2026-10-07T10:05:00Z",
    "created_at": "2026-10-07T10:00:00Z",
    "updated_at": "2026-10-07T10:05:00Z"
  }
]
```

---

### Get Single Device
- **Method**: `GET`
- **URL**: `/api/devices/{id}/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK): Returns device details.
- **Error** (404 Not Found): If device does not exist or belongs to another user.

---

### Delete Device
- **Method**: `DELETE`
- **URL**: `/api/devices/{id}/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Device deleted successfully."
}
```

---

## 3. Location & Tracking Endpoints

### Push Device Location
- **Method**: `POST`
- **URL**: `/api/devices/{id}/location/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Request Body**:
```json
{
  "latitude": 16.2356,
  "longitude": 80.0498,
  "accuracy": 10.5
}
```
- **Response** (201 Created):
```json
{
  "success": true,
  "timestamp": "2026-10-07T10:05:00Z"
}
```

---

### Get Latest Device Location
- **Method**: `GET`
- **URL**: `/api/devices/{id}/location/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "id": 501,
  "device": 101,
  "latitude": 16.2356,
  "longitude": 80.0498,
  "accuracy": 10.5,
  "timestamp": "2026-10-07T10:05:00Z"
}
```

---

### Get Device Location History
- **Method**: `GET`
- **URL**: `/api/devices/{id}/locations/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK): Paginated location history array.

---

## 4. Device Command Endpoints (Phase 6 Remote Control)

### Ring Device
- **Method**: `POST`
- **URL**: `/api/devices/{id}/ring/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Authorization**: Owner only (`device.user == request.user`)
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Ring command sent to device 'Pixel 8 Pro'",
  "device_id": 101
}
```
- **Error** (404 Not Found): If device does not exist or belongs to another user.
- **WebSocket Behavior**: Dispatches real-time `ring_command` event to connected target device group `traceup_device_{id}`.

---

### Enable Lost Mode
- **Method**: `POST`
- **URL**: `/api/devices/{id}/lost-mode/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Authorization**: Owner only (`device.user == request.user`)
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Lost mode enabled for device 'Pixel 8 Pro'",
  "device_id": 101,
  "is_lost_mode": true,
  "lost_mode_enabled_at": "2026-10-08T15:00:00.000000+00:00",
  "lost_mode_updated_at": "2026-10-08T15:00:00.000000+00:00"
}
```
- **Error** (404 Not Found): If device does not exist or belongs to another user.
- **WebSocket Behavior**: Dispatches real-time `lost_mode_update` broadcast to connected target device group `traceup_device_{id}` with `"is_lost_mode": true`.

---

### Disable Lost Mode
- **Method**: `DELETE`
- **URL**: `/api/devices/{id}/lost-mode/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Authorization**: Owner only (`device.user == request.user`)
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Lost mode disabled for device 'Pixel 8 Pro'",
  "device_id": 101,
  "is_lost_mode": false,
  "lost_mode_updated_at": "2026-10-08T15:10:00.000000+00:00"
}
```
- **Error** (404 Not Found): If device does not exist or belongs to another user.
- **WebSocket Behavior**: Dispatches real-time `lost_mode_update` broadcast to connected target device group `traceup_device_{id}` with `"is_lost_mode": false`.

---

### Get Lost Mode Status
- **Method**: `GET`
- **URL**: `/api/devices/{id}/lost-mode/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Authorization**: Owner only (`device.user == request.user`)
- **Response** (200 OK):
```json
{
  "device_id": 101,
  "is_lost_mode": true,
  "lost_mode_enabled_at": "2026-10-08T15:00:00.000000+00:00",
  "lost_mode_updated_at": "2026-10-08T15:00:00.000000+00:00"
}
```
- **Error** (404 Not Found): If device does not exist or belongs to another user.

---

## 5. Temporary Device State Endpoints (Redis Integration)

### Update Temporary Device State
- **Method**: `POST`
- **URL**: `/api/devices/{id}/state/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Request Body**:
```json
{
  "status": "online",
  "battery_level": 85,
  "ttl": 300
}
```
- **Response** (200 OK):
```json
{
  "device_id": 101,
  "status": "online",
  "last_activity": "2026-10-08T14:50:00+05:30",
  "battery_level": 85
}
```

---

### Get Temporary Device State
- **Method**: `GET`
- **URL**: `/api/devices/{id}/state/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "device_id": 101,
  "status": "online",
  "last_activity": "2026-10-08T14:50:00+05:30",
  "battery_level": 85,
  "ttl_remaining": 295
}
```
- **Error** (404 Not Found): If temporary state has expired in Redis or device does not exist/belong to authenticated user.

---

### Delete Temporary Device State
- **Method**: `DELETE`
- **URL**: `/api/devices/{id}/state/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "success": true,
  "deleted": true
}
```

---

## 6. Real-Time Tracking Endpoints (WebSocket Integration)

### Device Real-Time Location & Command WebSocket
- **Protocol**: `WS` / `WSS`
- **URL**: `ws://<SERVER_HOST>:<PORT>/ws/devices/{device_id}/?token=<JWT_ACCESS_TOKEN>`
- **Authentication**: JWT Access Token via query parameter `?token=<access_token>` or `Authorization` header (`Bearer <access_token>`).
- **Authorization**: Must own device (`device.user == request.user`). Unauthenticated connections are closed with code `4401`. Unauthorized device access is closed with code `4403`.

#### Client Location Update Payload:
```json
{
  "type": "location_update",
  "device_id": 101,
  "latitude": 17.6868,
  "longitude": 83.2185,
  "accuracy": 10.5
}
```

#### Server Broadcast Messages (to target device group `traceup_device_{device_id}`):

1. **Location Update Broadcast**:
```json
{
  "type": "location_update",
  "id": 502,
  "device_id": 101,
  "latitude": 17.6868,
  "longitude": 83.2185,
  "accuracy": 10.5,
  "timestamp": "2026-10-08T15:30:00.000000+00:00"
}
```

2. **Ring Command Message**:
```json
{
  "type": "ring_command",
  "device_id": 101
}
```

3. **Lost Mode Update Message**:
```json
{
  "type": "lost_mode_update",
  "device_id": 101,
  "is_lost_mode": true,
  "lost_mode_enabled_at": "2026-10-08T15:00:00.000000+00:00",
  "lost_mode_updated_at": "2026-10-08T15:00:00.000000+00:00"
}
```

#### Structured Error Response Format:
```json
{
  "type": "error",
  "code": "INVALID_LATITUDE",
  "message": "Latitude must be between -90 and 90."
}
```
- **Error Codes**: `MALFORMED_JSON`, `UNSUPPORTED_TYPE`, `DEVICE_ID_MISMATCH`, `MISSING_COORDINATES`, `INVALID_COORDINATES_TYPE`, `INVALID_LATITUDE`, `INVALID_LONGITUDE`, `INVALID_ACCURACY`.



