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

## 4. Device Command Endpoints

### Ring Device
- **Method**: `POST`
- **URL**: `/api/devices/{id}/ring/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Ring command sent to device 'Pixel 8 Pro'"
}
```

---

### Lost Mode
- **Method**: `POST`
- **URL**: `/api/devices/{id}/lost-mode/`
- **Authentication**: `Bearer <JWT_ACCESS_TOKEN>`
- **Response** (200 OK):
```json
{
  "success": true,
  "message": "Lost mode command sent to device 'Pixel 8 Pro'"
}
```

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

