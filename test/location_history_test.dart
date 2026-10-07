import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/screens/location/location_history_screen.dart';
import 'package:traceup/screens/devices/device_details_screen.dart';

void main() {
  final testDevice = DeviceModel(
    id: 101,
    name: 'Rajini Phone',
    deviceType: 'Android',
    isOnline: true,
    batteryLevel: 72,
    lastSeen: DateTime.now(),
  );

  group('LocationHistoryScreen Tests (Phase 7 - Location History)', () {
    testWidgets('LocationHistoryScreen renders device title, summary, and timeline items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LocationHistoryScreen(device: testDevice),
        ),
      );

      // Initial pump
      await tester.pump();
      // Pump for mock API delay (200ms)
      await tester.pump(const Duration(milliseconds: 300));

      // Title
      expect(find.text('Rajini Phone History'), findsOneWidget);

      // Summary Card
      expect(find.text('Total Logs'), findsOneWidget);
      expect(find.text('Latest Ping'), findsOneWidget);
      expect(find.text('GPS Accuracy'), findsOneWidget);

      // Timeline header
      expect(find.text('Movement Timeline'), findsOneWidget);

      // "Latest" tag on the latest ping
      expect(find.text('Latest'), findsOneWidget);

      // Coordinate labels
      expect(find.text('Latitude'), findsWidgets);
      expect(find.text('Longitude'), findsWidgets);
      expect(find.text('Accuracy'), findsWidgets);

      // Map action button in AppBar
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('LocationHistoryScreen displays empty state when device has no logs', (WidgetTester tester) async {
      final emptyDevice = DeviceModel(
        id: 999,
        name: 'Unsynced Device',
        deviceType: 'Android',
        isOnline: false,
        batteryLevel: 0,
        lastSeen: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LocationHistoryScreen(device: emptyDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Location History Found'), findsOneWidget);
      expect(find.textContaining('As this device reports its GPS coordinates'), findsOneWidget);
    });
  });

  group('DeviceDetailsScreen Location History Integration', () {
    testWidgets('DeviceDetailsScreen contains Location History operation tile', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeviceDetailsScreen(initialDevice: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final historyTile = find.text('Location History');
      expect(historyTile, findsOneWidget);
      expect(find.text('View chronological GPS timeline and logs'), findsOneWidget);
    });
  });
}
