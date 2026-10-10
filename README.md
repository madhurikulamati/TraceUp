# TraceUp - Flutter Frontend

TraceUp (Find My Device) is a cross-platform Flutter application for real-time mobile device tracking, remote security commands, interactive vector mapping, and location history.

Designed to integrate seamlessly with the TraceUp Django REST + Channels backend.

---

## Features

- **Authentication & Session Security**: Secure JWT authentication (login, registration, auto-session restore) with encrypted storage via `flutter_secure_storage`.
- **Interactive Vector Maps**: High-performance vector tile rendering powered by `maplibre_gl`, featuring multiple customizable vector map layers (TraceUp Navigation, OpenFreeMap Liberty & Bright, Carto Voyager & Dark Matter).
- **Valhalla Turn-by-Turn Routing**: Routing engine integration using OpenStreetMap Valhalla for live turn-by-turn navigation paths and ETA calculation.
- **Real-Time WebSocket Updates**: Live bi-directional WebSocket connection (`web_socket_channel`) with automatic reconnect backoff for live GPS marker streaming and ping actions.
- **Background Location Tracking**: Configurable background tracking profiles (Battery Saver, Balanced, High Accuracy) with Android foreground service notification support.
- **Remote Device Controls**:
  - **Ring / Play Sound**: Remote trigger at maximum volume with dialog controls.
  - **Lost Mode**: Remote device locking with custom contact phone number and recovery message display.
  - **Device Lock**: Remote screen locking.
- **Location History**: Timeline-based location breadcrumb history with speed, accuracy, and timestamp tracking.
- **Place Search**: Geocoding and auto-complete search powered by Photon / OpenStreetMap.
- **Adaptive Launcher Icons & Branding**: Modern beacon wave branding across Android adaptive icons, iOS AppIcon sets, and Web PWA assets.

---

## Architecture & Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart      # REST & WebSocket endpoint configurations
│   │   ├── app_assets.dart         # Asset paths
│   │   ├── app_colors.dart         # Color palette & branding tokens
│   │   ├── app_strings.dart        # UI strings & labels
│   │   └── map_constants.dart      # Vector map styles, tile providers, zoom presets
│   ├── theme/
│   │   └── app_theme.dart          # Light/Dark Material 3 theme configuration
│   └── utils/
│       ├── api_exception.dart      # Typed API error handling
│       └── app_routes.dart         # Route navigation names
├── models/                         # Strongly-typed data models
│   ├── device_model.dart
│   ├── location_model.dart
│   ├── lost_mode_model.dart
│   ├── place_search_result.dart
│   ├── tracking_mode_model.dart
│   ├── user_model.dart
│   ├── valhalla_route_model.dart
│   └── websocket_event_model.dart
├── screens/                        # UI Screens
│   ├── auth/                       # Login & Registration
│   ├── devices/                    # Device List, Details, Add Device, Lost Mode
│   ├── home/                       # Dashboard & Device Overview
│   ├── location/                   # Live Map, History, Background Tracking, GPS Status
│   ├── settings/                   # App Settings
│   └── splash/                     # Animated Splash Screen
├── services/                       # Business logic & API clients
│   ├── api_service.dart            # REST client with Bearer auth & Mock mode fallback
│   ├── auth_service.dart           # Authentication & token management
│   ├── background_location_service.dart # Background tracking engine
│   ├── device_service.dart         # Device CRUD & remote controls
│   ├── geocoding_service.dart      # OpenStreetMap Photon geocoder
│   ├── location_service.dart       # Geolocator GPS hardware manager
│   ├── valhalla_service.dart       # Valhalla routing API client
│   └── websocket_service.dart      # Real-time WebSocket manager
├── storage/
│   └── token_storage.dart          # Secure JWT token persistence
└── widgets/                        # Reusable UI components
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.13.5 or higher)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / VS Code with Flutter extension
- Android SDK (API 34 recommended) or connected physical Android device

### Installation

1. **Clone the repository and checkout the frontend branch:**
   ```bash
   git clone https://github.com/madhurikulamati/TraceUp.git
   cd TraceUp
   git checkout feature/flutter-frontend
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify code quality and tests:**
   ```bash
   flutter analyze
   flutter test
   ```

### Connecting to the Django Backend

By default, the application is configured with `ApiConstants.isMockMode = true` to allow standalone UI and flow testing without requiring an active backend server.

To connect to your live Django backend:

1. Open `lib/core/constants/api_constants.dart`.
2. Set `isMockMode = false`:
   ```dart
   static const bool isMockMode = false;
   ```
3. Update the `baseUrl` and `baseWsUrl`:
   - **For Android Emulator**:
     ```dart
     static const String baseUrl = 'http://10.0.2.2:8000/api/';
     static const String baseWsUrl = 'ws://10.0.2.2:8000/ws/';
     ```
   - **For Physical Device / LAN**:
     ```dart
     static const String baseUrl = 'http://<YOUR_LOCAL_IP>:8000/api/';
     static const String baseWsUrl = 'ws://<YOUR_LOCAL_IP>:8000/ws/';
     ```
   - **For Deployed Production Server**:
     ```dart
     static const String baseUrl = 'https://api.yourdomain.com/api/';
     static const String baseWsUrl = 'wss://api.yourdomain.com/ws/';
     ```

### Running the App

```bash
# Run on connected device or emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## Testing

All unit, model, and widget tests can be executed using:

```bash
flutter test
```

Current test suite covers:
- Authentication screens, form validation, and session handling
- Device list, addition, detail management, and operations
- GPS location permissions and fallback handling
- Valhalla routing and MapLibre map interactions
- WebSocket connection, status badges, and event streaming
- Remote controls (Play Sound dialog and Lost Mode locking)
