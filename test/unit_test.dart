import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/utils/api_exception.dart';
import 'package:traceup/models/user_model.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/services/auth_service.dart';
import 'package:traceup/services/device_service.dart';
import 'package:traceup/storage/token_storage.dart';

void main() {
  group('Model Serialization Tests', () {
    test('UserModel fromJson and toJson match backend schema', () {
      final json = {
        'id': 1,
        'name': 'Rajini',
        'email': 'user@example.com',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 1);
      expect(user.name, 'Rajini');
      expect(user.email, 'user@example.com');
      expect(user.toJson(), json);
    });

    test('DeviceModel fromJson and toJson match backend schema', () {
      final json = {
        'id': 101,
        'name': 'Rajini Phone',
        'device_type': 'Android',
        'is_online': true,
        'battery_level': 72,
        'last_seen': '2026-10-07T10:00:00.000Z',
      };

      final device = DeviceModel.fromJson(json);
      expect(device.id, 101);
      expect(device.name, 'Rajini Phone');
      expect(device.deviceType, 'Android');
      expect(device.isOnline, true);
      expect(device.batteryLevel, 72);
      expect(device.toJson()['id'], 101);
      expect(device.toJson()['name'], 'Rajini Phone');
      expect(device.toJson()['is_online'], true);
    });
  });

  group('ApiException Tests (Section 18)', () {
    test('ApiException returns friendly message for 401 Unauthorized', () {
      final exception = ApiException.fromStatusCode(401);
      expect(exception.message, contains('Invalid email or password'));
      expect(exception.statusCode, 401);
    });

    test('ApiException returns friendly message for 403 Forbidden', () {
      final exception = ApiException.fromStatusCode(403);
      expect(exception.message, contains('permission'));
      expect(exception.statusCode, 403);
    });

    test('ApiException returns friendly message for 404 Not Found', () {
      final exception = ApiException.fromStatusCode(404);
      expect(exception.message, contains('not found'));
      expect(exception.statusCode, 404);
    });

    test('ApiException returns friendly message for 500 Server Error', () {
      final exception = ApiException.fromStatusCode(500);
      expect(exception.message, contains('Server error'));
      expect(exception.statusCode, 500);
    });

    test('ApiException handles No Internet and Timeout scenarios', () {
      final noInternet = ApiException.noInternet();
      expect(noInternet.message, contains('No internet connection'));
      expect(noInternet.type, ApiExceptionType.noInternet);

      final timeout = ApiException.timeout();
      expect(timeout.message, contains('timed out'));
      expect(timeout.type, ApiExceptionType.timeout);
    });
  });

  group('TokenStorage Tests (Section 19)', () {
    test('TokenStorage correctly saves, retrieves, and clears JWT tokens', () async {
      final storage = TokenStorage();
      await storage.clearAll();

      expect(await storage.hasToken(), false);

      await storage.saveTokens(
        accessToken: 'test_access_token_123',
        refreshToken: 'test_refresh_token_456',
      );

      expect(await storage.hasToken(), true);
      expect(await storage.getAccessToken(), 'test_access_token_123');
      expect(await storage.getRefreshToken(), 'test_refresh_token_456');

      await storage.clearAll();
      expect(await storage.hasToken(), false);
      expect(await storage.getAccessToken(), isNull);
    });
  });

  group('AuthService Tests (Section 9)', () {
    final authService = AuthService();

    setUp(() async {
      await authService.logout();
    });

    test('Successful login sets tokens and returns user model', () async {
      final user = await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );

      expect(user.email, 'user@example.com');
      expect(await authService.isLoggedIn(), true);
      expect(authService.currentUser?.email, 'user@example.com');
    });

    test('Failed login with invalid credentials throws ApiException with 401', () async {
      expect(
        () => authService.login(
          email: 'user@example.com',
          password: 'wrongpassword',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('Registration sets tokens and retrieves current user', () async {
      final user = await authService.register(
        name: 'New Registered User',
        email: 'newuser@example.com',
        password: 'password123',
      );

      expect(user.name, 'New Registered User');
      expect(user.email, 'newuser@example.com');
      expect(await authService.isLoggedIn(), true);

      final fetchedUser = await authService.getCurrentUser();
      expect(fetchedUser?.email, 'newuser@example.com');
    });

    test('Logout clears all tokens and session state', () async {
      await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );
      expect(await authService.isLoggedIn(), true);

      await authService.logout();
      expect(await authService.isLoggedIn(), false);
      expect(authService.currentUser, isNull);
    });
  });

  group('DeviceService Tests', () {
    test('DeviceService retrieves and modifies mock devices', () async {
      final deviceService = DeviceService();

      final initialDevices = await deviceService.getDevices();
      expect(initialDevices.isNotEmpty, true);

      final firstDevice = await deviceService.getDeviceById(initialDevices.first.id);
      expect(firstDevice.id, initialDevices.first.id);

      final addedDevice = await deviceService.addDevice(
        name: 'Test Device',
        deviceType: 'Android',
      );
      expect(addedDevice.name, 'Test Device');

      final updatedDevices = await deviceService.getDevices();
      expect(updatedDevices.any((d) => d.id == addedDevice.id), true);

      final deleteResult = await deviceService.deleteDevice(addedDevice.id);
      expect(deleteResult, true);
    });
  });
}
