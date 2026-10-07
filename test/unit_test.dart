import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/models/user_model.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/services/auth_service.dart';
import 'package:traceup/services/device_service.dart';

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

  group('Service Mock Tests', () {
    test('AuthService login, register, and logout workflow', () async {
      final authService = AuthService();

      // Ensure logged out initially
      await authService.logout();
      expect(await authService.isLoggedIn(), false);

      // Perform login
      final user = await authService.login(
        email: 'user@example.com',
        password: 'password123',
      );
      expect(user.email, 'user@example.com');
      expect(await authService.isLoggedIn(), true);

      // Perform logout
      await authService.logout();
      expect(await authService.isLoggedIn(), false);
      expect(authService.currentUser, isNull);
    });

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
