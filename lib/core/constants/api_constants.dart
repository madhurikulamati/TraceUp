class ApiConstants {
  // Base server URL (configured for local dev / emulator / production)
  // Android emulator typically accesses host machine at 10.0.2.2:8000
  static const String baseUrl = 'http://10.0.2.2:8000/api/';

  // Toggle for Mock API Mode (Backend independent development)
  static const bool isMockMode = true;

  // MapLibre Vector Map Style URL
  static const String mapLibreStyleUrl = 'https://demotiles.maplibre.org/style.json';

  // Valhalla OpenStreetMap Routing Engine endpoint
  static const String valhallaBaseUrl = 'https://valhalla1.openstreetmap.de/route';

  // Authentication endpoints
  static const String registerEndpoint = 'auth/register/';
  static const String loginEndpoint = 'auth/login/';
  static const String meEndpoint = 'auth/me/';

  // Device endpoints
  static const String devicesEndpoint = 'devices/';
  static String deviceDetailEndpoint(int id) => 'devices/$id/';
  static String deviceLocationEndpoint(int id) => 'devices/$id/location/';
  static String deviceLocationsEndpoint(int id) => 'devices/$id/locations/';

  // WebSocket endpoints
  static const String baseWsUrl = 'ws://10.0.2.2:8000/ws/';
  static String deviceWsEndpoint(int deviceId) => 'devices/$deviceId/';
  static Uri deviceWsUri(int deviceId) => Uri.parse('$baseWsUrl${deviceWsEndpoint(deviceId)}');
}
