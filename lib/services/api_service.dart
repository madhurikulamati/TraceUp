import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../core/utils/api_exception.dart';
import '../storage/token_storage.dart';

/// ApiService handles all REST API network communication.
/// Adheres strictly to the Backend API Contract.
/// Includes Mock Mode for concurrent frontend/backend development.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  final TokenStorage _tokenStorage = TokenStorage();

  bool get isMock => ApiConstants.isMockMode;
  String get baseUrl => ApiConstants.baseUrl;

  static const Duration timeoutDuration = Duration(seconds: 15);

  // In-memory mock store for locations
  final Map<int, Map<String, dynamic>> _mockDeviceLocations = {
    101: {
      'device_id': 101,
      'latitude': 16.2356,
      'longitude': 80.0498,
      'accuracy': 10.5,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    },
  };

  final Map<int, List<Map<String, dynamic>>> _mockLocationHistories = {
    101: [
      {
        'device_id': 101,
        'latitude': 16.2350,
        'longitude': 80.0490,
        'accuracy': 12.0,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      },
      {
        'device_id': 101,
        'latitude': 16.2356,
        'longitude': 80.0498,
        'accuracy': 10.5,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
    ],
  };

  /// Performs GET request with automatic Bearer token injection
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _handleMockGet(endpoint);
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = await _buildHeaders(headers);

      final response = await _client
          .get(uri, headers: requestHeaders)
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException.noInternet();
    } on TimeoutException {
      throw ApiException.timeout();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Performs POST request with automatic Bearer token injection
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 250));
      return _handleMockPost(endpoint, data);
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = await _buildHeaders(headers);

      final response = await _client
          .post(
            uri,
            headers: requestHeaders,
            body: data != null ? jsonEncode(data) : null,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException.noInternet();
    } on TimeoutException {
      throw ApiException.timeout();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  /// Performs DELETE request with automatic Bearer token injection
  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {'success': true};
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final requestHeaders = await _buildHeaders(headers);

      final response = await _client
          .delete(uri, headers: requestHeaders)
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException.noInternet();
    } on TimeoutException {
      throw ApiException.timeout();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException.invalidResponse();
    }
  }

  Future<Map<String, String>> _buildHeaders(Map<String, String>? customHeaders) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic responseData;
    try {
      if (response.body.isNotEmpty) {
        responseData = jsonDecode(response.body);
      }
    } catch (_) {
      throw ApiException.invalidResponse();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    String? serverErrorMsg;
    if (responseData is Map<String, dynamic>) {
      serverErrorMsg = responseData['detail'] ??
          responseData['message'] ??
          responseData['error'];
    }

    throw ApiException.fromStatusCode(response.statusCode, serverErrorMsg);
  }

  // --- Mock Handlers ---
  dynamic _handleMockGet(String endpoint) {
    if (endpoint == ApiConstants.meEndpoint) {
      return {
        'id': 1,
        'name': 'Rajini',
        'email': 'user@example.com',
      };
    }
    if (endpoint == ApiConstants.devicesEndpoint) {
      return [
        {
          'id': 101,
          'name': 'Rajini Phone',
          'device_type': 'Android',
          'is_online': true,
          'battery_level': 72,
          'last_seen': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
        {
          'id': 102,
          'name': 'Work Tablet',
          'device_type': 'Android',
          'is_online': false,
          'battery_level': 45,
          'last_seen': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        }
      ];
    }

    // Match GET /devices/{id}/locations/
    final locationsRegex = RegExp(r'^devices/(\d+)/locations/?$');
    final matchLocations = locationsRegex.firstMatch(endpoint);
    if (matchLocations != null) {
      final deviceId = int.parse(matchLocations.group(1)!);
      return _mockLocationHistories[deviceId] ?? [];
    }

    // Match GET /devices/{id}/location/
    final locationRegex = RegExp(r'^devices/(\d+)/location/?$');
    final matchLocation = locationRegex.firstMatch(endpoint);
    if (matchLocation != null) {
      final deviceId = int.parse(matchLocation.group(1)!);
      return _mockDeviceLocations[deviceId] ?? {
        'device_id': deviceId,
        'latitude': 16.2356,
        'longitude': 80.0498,
        'accuracy': 10.5,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    return {};
  }

  dynamic _handleMockPost(String endpoint, Map<String, dynamic>? data) {
    if (endpoint == ApiConstants.loginEndpoint) {
      final email = data?['email'] as String? ?? 'user@example.com';
      final password = data?['password'] as String? ?? '';

      if (password == 'wrongpassword') {
        throw const ApiException(
          message: 'Invalid email or password. Please try again.',
          statusCode: 401,
          type: ApiExceptionType.unauthorized,
        );
      }

      return {
        'access': 'mock_jwt_access_token_header.payload.signature',
        'refresh': 'mock_jwt_refresh_token_header.payload.signature',
        'user': {
          'id': 1,
          'name': email.contains('@') ? email.split('@').first : 'Rajini',
          'email': email,
        },
      };
    }

    if (endpoint == ApiConstants.registerEndpoint) {
      final name = data?['name'] as String? ?? 'Rajini';
      final email = data?['email'] as String? ?? 'user@example.com';

      return {
        'access': 'mock_jwt_access_token_registered',
        'refresh': 'mock_jwt_refresh_token_registered',
        'user': {
          'id': 2,
          'name': name,
          'email': email,
        },
      };
    }

    // Match POST /devices/{id}/location/
    final locationRegex = RegExp(r'^devices/(\d+)/location/?$');
    final match = locationRegex.firstMatch(endpoint);
    if (match != null) {
      final deviceId = int.parse(match.group(1)!);
      final timestamp = DateTime.now().toIso8601String();
      final locationData = {
        'device_id': deviceId,
        'latitude': (data?['latitude'] as num?)?.toDouble() ?? 16.2356,
        'longitude': (data?['longitude'] as num?)?.toDouble() ?? 80.0498,
        'accuracy': (data?['accuracy'] as num?)?.toDouble() ?? 10.0,
        'timestamp': timestamp,
      };

      _mockDeviceLocations[deviceId] = locationData;
      _mockLocationHistories.putIfAbsent(deviceId, () => []).add(locationData);

      return {
        'success': true,
        'timestamp': timestamp,
      };
    }

    return {'success': true};
  }
}
