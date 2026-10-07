import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/models/location_model.dart';
import 'package:traceup/services/device_service.dart';
import 'package:traceup/services/location_service.dart';
import 'package:traceup/screens/devices/device_details_screen.dart';

void main() {
  group('Send Location Service Tests (Section 12)', () {
    final deviceService = DeviceService();
    final locationService = LocationService();

    test('sendDeviceLocation transmits dynamic GPS coordinates', () async {
      // Dynamic non-hardcoded coordinates
      final dynamicLoc = LocationModel(
        latitude: 17.3850,
        longitude: 78.4867,
        accuracy: 8.4,
        timestamp: DateTime.now(),
      );

      final response = await deviceService.sendDeviceLocation(
        deviceId: 101,
        location: dynamicLoc,
      );

      expect(response['success'], true);
      expect(response['timestamp'], isNotNull);

      // Verify getDeviceLocation returns the newly updated position
      final fetched = await deviceService.getDeviceLocation(101);
      expect(fetched.latitude, 17.3850);
      expect(fetched.longitude, 78.4867);
      expect(fetched.accuracy, 8.4);
    });

    test('syncCurrentLocationToServer captures live GPS and posts to server', () async {
      final customGps = LocationModel(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracy: 6.2,
        timestamp: DateTime.now(),
      );
      locationService.setMockLocation(customGps);

      final synced = await deviceService.syncCurrentLocationToServer(
        deviceId: 101,
        locationService: locationService,
      );

      expect(synced.latitude, 12.9716);
      expect(synced.longitude, 77.5946);
      expect(synced.accuracy, 6.2);

      final serverLatest = await deviceService.getDeviceLocation(101);
      expect(serverLatest.latitude, 12.9716);
      expect(serverLatest.longitude, 77.5946);
    });
  });

  group('Send Location UI Widget Tests', () {
    testWidgets('DeviceDetailsScreen displays location card and transmit button', (WidgetTester tester) async {
      final testDevice = DeviceModel(
        id: 101,
        name: 'Rajini Phone',
        deviceType: 'Android',
        isOnline: true,
        batteryLevel: 85,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeviceDetailsScreen(initialDevice: testDevice),
        ),
      );

      // Allow device and location load timers to resolve
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Recorded GPS Location'), findsOneWidget);
      final transmitBtn = find.text('Transmit Current Location to Server');
      expect(transmitBtn, findsOneWidget);

      // Scroll into view and tap transmit button
      await tester.ensureVisible(transmitBtn);
      await tester.pumpAndSettle();

      await tester.tap(transmitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('GPS coordinates uploaded to server'), findsOneWidget);
    });
  });
}
