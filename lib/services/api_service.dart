import '../core/constants/api_constants.dart';

/// ApiService provides HTTP client abstraction and mock response fallback.
/// Designed so UI never breaks when switching between Mock and Real Django API.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  bool get isMock => ApiConstants.isMockMode;

  String get baseUrl => ApiConstants.baseUrl;

  // Placeholder for real HTTP requests (Phase 2 integration with Dio/http)
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
    if (isMock) {
      // Mock route dispatcher
      return _handleMockGet(endpoint);
    }
    throw UnimplementedError('Real backend integration will be activated in Phase 2.');
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? data, Map<String, String>? headers}) async {
    if (isMock) {
      return _handleMockPost(endpoint, data);
    }
    throw UnimplementedError('Real backend integration will be activated in Phase 2.');
  }

  Map<String, dynamic> _handleMockGet(String endpoint) {
    if (endpoint == ApiConstants.meEndpoint) {
      return {
        'id': 1,
        'name': 'Rajini',
        'email': 'user@example.com',
      };
    }
    return {};
  }

  Map<String, dynamic> _handleMockPost(String endpoint, Map<String, dynamic>? data) {
    if (endpoint == ApiConstants.loginEndpoint) {
      return {
        'access': 'mock_jwt_access_token_xyz',
        'refresh': 'mock_jwt_refresh_token_abc',
        'user': {
          'id': 1,
          'name': 'Rajini',
          'email': data?['email'] ?? 'user@example.com',
        },
      };
    }
    if (endpoint == ApiConstants.registerEndpoint) {
      return {
        'access': 'mock_jwt_access_token_new',
        'refresh': 'mock_jwt_refresh_token_new',
        'user': {
          'id': 2,
          'name': data?['name'] ?? 'New User',
          'email': data?['email'] ?? 'newuser@example.com',
        },
      };
    }
    return {'success': true};
  }
}
