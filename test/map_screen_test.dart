import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/models/valhalla_route_model.dart';
import 'package:traceup/services/valhalla_service.dart';
import 'package:traceup/screens/location/map_screen.dart';

void main() {
  group('ValhallaRouteModel Tests (Section 13 & Valhalla)', () {
    test('ValhallaRouteModel formats duration and distance correctly', () {
      const model = ValhallaRouteModel(
        distanceKm: 5.42,
        durationSeconds: 930, // ~16 mins
        polylineCoordinates: [
          [80.0498, 16.2356],
          [80.0550, 16.2400],
        ],
        maneuvers: [
          'Depart towards Main Rd',
          'Turn right onto Station Rd',
          'Arrive at Rajini Phone',
        ],
      );

      expect(model.distanceFormatted, '5.4 km');
      expect(model.durationFormatted, '16 mins');
      expect(model.maneuvers.length, 3);
    });

    test('ValhallaService generates route between user and device', () async {
      final valhallaService = ValhallaService();

      final route = await valhallaService.getRoute(
        startLat: 16.2300,
        startLon: 80.0400,
        endLat: 16.2356,
        endLon: 80.0498,
      );

      expect(route.distanceKm, greaterThan(0));
      expect(route.durationSeconds, greaterThan(0));
      expect(route.maneuvers.isNotEmpty, true);
    });
  });

  group('MapScreen Widget Tests (Section 13 & MapLibre)', () {
    testWidgets('MapScreen renders device info, coordinates, and Valhalla routing', (WidgetTester tester) async {
      final testDevice = DeviceModel(
        id: 101,
        name: 'Rajini Phone',
        deviceType: 'Android',
        isOnline: true,
        batteryLevel: 72,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MapScreen(device: testDevice),
        ),
      );

      // Allow device location fetch timer to complete
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rajini Phone Location'), findsOneWidget);
      expect(find.text('Rajini Phone'), findsOneWidget);
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Route with Valhalla'), findsOneWidget);

      // Test tapping Route with Valhalla button
      await tester.tap(find.text('Route with Valhalla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Valhalla bottom sheet is displayed
      expect(find.text('Valhalla Route'), findsOneWidget);
      expect(find.text('Turn-by-Turn Directions:'), findsOneWidget);
    });
  });
}
