import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/models/websocket_event_model.dart';
import 'package:traceup/services/websocket_service.dart';
import 'package:traceup/screens/location/map_screen.dart';

void main() {
  group('WebSocketEvent Model Tests', () {
    test('Parses location_update event correctly', () {
      final json = {
        'type': 'location_update',
        'device_id': 101,
        'latitude': 16.2356,
        'longitude': 80.0498,
        'accuracy': 7.5,
        'timestamp': '2026-10-07T13:20:00Z',
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, WebSocketEventType.locationUpdate);
      expect(event.deviceId, 101);
      expect(event.location, isNotNull);
      expect(event.location!.latitude, 16.2356);
      expect(event.location!.longitude, 80.0498);
      expect(event.location!.accuracy, 7.5);
    });

    test('Parses device_status event correctly', () {
      final json = {
        'type': 'device_status',
        'device_id': 101,
        'is_online': true,
        'battery_level': 88,
      };

      final event = WebSocketEvent.fromJson(json);

      expect(event.type, WebSocketEventType.deviceStatus);
      expect(event.deviceId, 101);
      expect(event.isOnline, true);
      expect(event.batteryLevel, 88);
    });
  });

  group('WebSocketService Lifecycle and Streaming Tests', () {
    late WebSocketService service;

    setUp(() {
      service = WebSocketService();
    });

    tearDown(() async {
      await service.disconnect();
    });

    test('Connects in mock mode and emits connected status', () async {
      final statuses = <WebSocketConnectionStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      await service.connect(101);
      await Future.delayed(const Duration(milliseconds: 350));

      expect(statuses, contains(WebSocketConnectionStatus.connected));
      expect(service.currentStatus, WebSocketConnectionStatus.connected);

      await sub.cancel();
    });

    test('Receives simulated live location updates through locationUpdates stream', () async {
      final locations = [];
      final sub = service.locationUpdates.listen(locations.add);

      await service.connect(101);
      await Future.delayed(const Duration(milliseconds: 350));

      service.simulateLocationUpdate(
        latitude: 16.2400,
        longitude: 80.0550,
        accuracy: 5.0,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(locations.isNotEmpty, true);
      final latest = locations.last;
      expect(latest.latitude, 16.2400);
      expect(latest.longitude, 80.0550);

      await sub.cancel();
    });

    test('sendLocationPing loops back through event stream in mock mode', () async {
      final events = <WebSocketEvent>[];
      final sub = service.eventStream.listen(events.add);

      await service.connect(101);
      await Future.delayed(const Duration(milliseconds: 350));

      service.sendLocationPing(
        latitude: 16.2500,
        longitude: 80.0600,
        accuracy: 4.0,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events.isNotEmpty, true);
      final lastEvent = events.last;
      expect(lastEvent.type, WebSocketEventType.locationUpdate);
      expect(lastEvent.location?.latitude, 16.2500);

      await sub.cancel();
    });
  });

  group('MapScreen Real-Time WebSocket Integration Widget Tests', () {
    final testDevice = DeviceModel(
      id: 101,
      name: 'Rajini Phone',
      deviceType: 'Android',
      isOnline: true,
      batteryLevel: 72,
      lastSeen: DateTime.now(),
    );

    testWidgets('MapScreen connects to WebSocket and displays Live WebSocket status badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MapScreen(device: testDevice),
        ),
      );

      await tester.pump();
      // Pump past mock handshake
      await tester.pump(const Duration(milliseconds: 400));

      // Check for Live WebSocket badge
      expect(find.text('Live WebSocket'), findsOneWidget);

      // Check for Simulate Live GPS Ping action icon in AppBar
      expect(find.byIcon(Icons.satellite_alt_rounded), findsOneWidget);
    });

    testWidgets('Tapping simulate ping button emits new coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MapScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pingButton = find.byIcon(Icons.satellite_alt_rounded);
      expect(pingButton, findsOneWidget);

      await tester.tap(pingButton);
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar feedback shown
      expect(find.text('Simulated live GPS ping broadcast via WebSocket'), findsOneWidget);
    });
  });
}
