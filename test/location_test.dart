import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/location_model.dart';
import 'package:traceup/services/location_service.dart';
import 'package:traceup/screens/location/location_status_screen.dart';

void main() {
  group('LocationModel Tests', () {
    test('LocationModel serializes and deserializes according to Section 6 API', () {
      final json = {
        'device_id': 101,
        'latitude': 16.2356,
        'longitude': 80.0498,
        'accuracy': 10.5,
        'timestamp': '2026-10-07T10:00:00.000Z',
      };

      final model = LocationModel.fromJson(json);
      expect(model.deviceId, 101);
      expect(model.latitude, 16.2356);
      expect(model.longitude, 80.0498);
      expect(model.accuracy, 10.5);

      final postPayload = model.toPostPayload();
      expect(postPayload['latitude'], 16.2356);
      expect(postPayload['longitude'], 80.0498);
      expect(postPayload['accuracy'], 10.5);
      expect(postPayload.containsKey('device_id'), false);
    });
  });

  group('LocationService Tests (Section 11)', () {
    final locationService = LocationService();

    test('LocationService checks service enabled and permissions safely', () async {
      final isEnabled = await locationService.isLocationServiceEnabled();
      expect(isEnabled, true);

      final permission = await locationService.checkPermission();
      expect(permission, isA<LocationPermission>());

      final requested = await locationService.requestPermission();
      expect(requested, isA<LocationPermission>());
    });

    test('LocationService acquires current location coordinates', () async {
      final customLocation = LocationModel(
        latitude: 16.2356,
        longitude: 80.0498,
        accuracy: 10.5,
        timestamp: DateTime.now(),
      );
      locationService.setMockLocation(customLocation);

      final loc = await locationService.getCurrentLocation();
      expect(loc.latitude, 16.2356);
      expect(loc.longitude, 80.0498);
      expect(loc.accuracy, 10.5);
      expect(loc.timestamp, isNotNull);
    });
  });

  group('LocationStatusScreen Widget Tests', () {
    testWidgets('LocationStatusScreen displays GPS metrics and refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LocationStatusScreen(),
        ),
      );

      // Allow initial location fetch
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('GPS & Location'), findsOneWidget);
      expect(find.text('Device GPS Sensor'), findsOneWidget);
      expect(find.text('Current Position'), findsOneWidget);
      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('Acquire Current Location'), findsOneWidget);

      // Verify coordinate values are rendered
      expect(find.text('16.235600°'), findsOneWidget);
      expect(find.text('80.049800°'), findsOneWidget);
      expect(find.text('±10.5 m'), findsOneWidget);

      // Test tapping acquire button
      await tester.tap(find.text('Acquire Current Location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Acquired'), findsOneWidget);
    });
  });
}
