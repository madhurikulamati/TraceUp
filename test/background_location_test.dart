import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/models/tracking_mode_model.dart';
import 'package:traceup/services/background_location_service.dart';
import 'package:traceup/screens/location/background_tracking_screen.dart';
import 'package:traceup/screens/devices/device_details_screen.dart';

void main() {
  group('TrackingMode Model & Battery Profiles', () {
    test('Default intervals and distance filters match battery profiles', () {
      expect(TrackingMode.balanced.defaultIntervalMinutes, 15);
      expect(TrackingMode.balanced.distanceFilterMeters, 100);
      expect(TrackingMode.balanced.title, 'Balanced');

      expect(TrackingMode.active.defaultIntervalMinutes, 1);
      expect(TrackingMode.active.distanceFilterMeters, 10);
      expect(TrackingMode.active.title, 'High Frequency');

      expect(TrackingMode.batterySaver.defaultIntervalMinutes, 30);
      expect(TrackingMode.batterySaver.distanceFilterMeters, 500);
      expect(TrackingMode.batterySaver.title, 'Battery Saver');
    });
  });

  group('BackgroundLocationService Lifecycle', () {
    late BackgroundLocationService service;

    setUp(() {
      service = BackgroundLocationService();
    });

    tearDown(() async {
      await service.stopTracking();
    });

    test('startTracking updates tracking state, mode, and executes immediate sync', () async {
      expect(service.isTracking, false);

      final success = await service.startTracking(
        deviceId: 101,
        mode: TrackingMode.active,
      );

      expect(success, true);
      expect(service.isTracking, true);
      expect(service.currentMode, TrackingMode.active);
      expect(service.intervalMinutes, 1);
      expect(service.pingsSentCount, greaterThan(0));
      expect(service.lastKnownLocation, isNotNull);
    });

    test('setTrackingMode modifies mode and interval', () async {
      await service.startTracking(deviceId: 101, mode: TrackingMode.balanced);
      expect(service.currentMode, TrackingMode.balanced);
      expect(service.intervalMinutes, 15);

      await service.setTrackingMode(TrackingMode.batterySaver);
      expect(service.currentMode, TrackingMode.batterySaver);
      expect(service.intervalMinutes, 30);
    });

    test('stopTracking deactivates background tracking', () async {
      await service.startTracking(deviceId: 101);
      expect(service.isTracking, true);

      await service.stopTracking();
      expect(service.isTracking, false);
    });
  });

  group('BackgroundTrackingScreen Widget Tests', () {
    final testDevice = DeviceModel(
      id: 101,
      name: 'Rajini Phone',
      deviceType: 'Android',
      isOnline: true,
      batteryLevel: 72,
      lastSeen: DateTime.now(),
    );

    setUp(() async {
      await BackgroundLocationService().stopTracking();
    });

    tearDown(() async {
      await BackgroundLocationService().stopTracking();
    });

    testWidgets('BackgroundTrackingScreen renders master switch, profiles, and metrics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BackgroundTrackingScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header switch
      expect(find.text('Background Tracking'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Battery Profiles
      expect(find.text('Battery & Tracking Profiles'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('High Frequency'), findsOneWidget);
      expect(find.text('Battery Saver'), findsOneWidget);

      // Metrics
      expect(find.text('Tracking Metrics'), findsOneWidget);
      expect(find.text('Pings Sent'), findsOneWidget);

      // Notification Preview
      expect(find.text('Android Foreground Notification Preview'), findsOneWidget);
      expect(find.text('TraceUp Protection Active'), findsOneWidget);

      // Force Sync Button
      expect(find.text('Force GPS Sync Now'), findsOneWidget);
    });

    testWidgets('Tapping profile updates selected tracking mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BackgroundTrackingScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on High Frequency card
      final highFreqCard = find.text('High Frequency');
      expect(highFreqCard, findsOneWidget);

      await tester.tap(highFreqCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SnackBar confirmation
      expect(find.text('Switched to High Frequency tracking profile'), findsOneWidget);
    });

    testWidgets('Toggling master switch updates tracking state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BackgroundTrackingScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle ON
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Background protection enabled'), findsOneWidget);
    });
  });

  group('DeviceDetailsScreen Background Protection Integration', () {
    testWidgets('DeviceDetailsScreen contains Background Protection operation tile', (WidgetTester tester) async {
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
          home: DeviceDetailsScreen(initialDevice: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Background Protection'), findsOneWidget);
      expect(find.text('Configure automated background tracking & intervals'), findsOneWidget);
    });
  });
}
