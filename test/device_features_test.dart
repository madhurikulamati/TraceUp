import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/models/lost_mode_model.dart';
import 'package:traceup/services/device_service.dart';
import 'package:traceup/screens/devices/lost_mode_screen.dart';
import 'package:traceup/screens/devices/device_details_screen.dart';
import 'package:traceup/widgets/play_sound_dialog.dart';

void main() {
  final testDevice = DeviceModel(
    id: 101,
    name: 'Rajini Phone',
    deviceType: 'Android',
    isOnline: true,
    batteryLevel: 72,
    lastSeen: DateTime.now(),
  );

  group('LostModeModel Data Tests', () {
    test('LostModeModel serialization and deserialization works correctly', () {
      final json = {
        'device_id': 101,
        'is_lost': true,
        'phone_number': '+91 98765 43210',
        'message': 'Please return my phone!',
        'updated_at': '2026-10-07T12:00:00.000Z',
      };

      final model = LostModeModel.fromJson(json);
      expect(model.deviceId, 101);
      expect(model.isLost, true);
      expect(model.phoneNumber, '+91 98765 43210');
      expect(model.message, 'Please return my phone!');

      final out = model.toJson();
      expect(out['device_id'], 101);
      expect(out['is_lost'], true);
      expect(out['phone_number'], '+91 98765 43210');
    });
  });

  group('DeviceService Remote Controls Service Tests (Phase 10)', () {
    final deviceService = DeviceService();

    test('playSound and stopSound dispatch remote sound alert commands', () async {
      final playResp = await deviceService.playSound(101);
      expect(playResp['status'], 'playing');

      final stopResp = await deviceService.stopSound(101);
      expect(stopResp['status'], 'stopped');
    });

    test('getLostMode, setLostMode, and lockDevice modify and retrieve remote state', () async {
      final initial = await deviceService.getLostMode(101);
      expect(initial.deviceId, 101);

      final updated = await deviceService.setLostMode(
        101,
        isLost: true,
        phoneNumber: '9988776655',
        message: 'Reward offered!',
      );
      expect(updated.isLost, true);
      expect(updated.phoneNumber, '9988776655');
      expect(updated.message, 'Reward offered!');

      final lockResp = await deviceService.lockDevice(101, lockMessage: 'Secured');
      expect(lockResp['status'], 'locked');
    });
  });

  group('PlaySoundDialog Widget Tests', () {
    testWidgets('PlaySoundDialog displays device title, volume notice, countdown and stop button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PlaySoundDialog.show(context, deviceId: 101, deviceName: 'Rajini Phone');
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ringing Rajini Phone...'), findsOneWidget);
      expect(find.text('Playing at maximum volume (overrides silent)'), findsOneWidget);
      expect(find.textContaining('Auto-stop in:'), findsOneWidget);

      final stopButton = find.text('Stop Ringing');
      expect(stopButton, findsOneWidget);

      await tester.tap(stopButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is dismissed
      expect(find.text('Ringing Rajini Phone...'), findsNothing);
    });
  });

  group('LostModeScreen Widget Tests', () {
    setUp(() async {
      await DeviceService().setLostMode(
        101,
        isLost: false,
        phoneNumber: '',
        message: 'This device is lost. Please call me if found!',
      );
    });

    tearDown(() async {
      await DeviceService().setLostMode(
        101,
        isLost: false,
        phoneNumber: '',
        message: 'This device is lost. Please call me if found!',
      );
    });

    testWidgets('LostModeScreen renders status banner, input fields, and lock preview', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LostModeScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rajini Phone Lost Mode'), findsOneWidget);
      expect(find.text('Contact Phone Number'), findsOneWidget);
      expect(find.text('Lock Screen Recovery Message'), findsOneWidget);

      // Lock Screen Preview
      expect(find.text('THIS DEVICE IS LOST'), findsOneWidget);
      expect(find.textContaining('Call '), findsOneWidget);

      // Button
      expect(find.text('Activate Lost Mode'), findsOneWidget);
    });

    testWidgets('Activating Lost Mode updates status and shows confirmation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LostModeScreen(device: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter phone
      final phoneField = find.byType(TextFormField).first;
      await tester.enterText(phoneField, '9876543210');
      await tester.pump();

      final activateButton = find.text('Activate Lost Mode');
      expect(activateButton, findsOneWidget);

      await tester.ensureVisible(activateButton);
      await tester.tap(activateButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Deactivate button now present and snackbar shown
      expect(find.textContaining('Lost Mode enabled'), findsOneWidget);
      expect(find.text('Deactivate Lost Mode'), findsOneWidget);
    });
  });

  group('DeviceDetailsScreen Phase 10 Remote Controls Integration', () {
    setUp(() async {
      await DeviceService().setLostMode(
        101,
        isLost: false,
        phoneNumber: '',
        message: 'This device is lost. Please call me if found!',
      );
    });

    tearDown(() async {
      await DeviceService().setLostMode(
        101,
        isLost: false,
        phoneNumber: '',
        message: 'This device is lost. Please call me if found!',
      );
    });

    testWidgets('DeviceDetailsScreen opens PlaySoundDialog when Play Sound is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeviceDetailsScreen(initialDevice: testDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final playSoundTile = find.text('Play Sound');
      expect(playSoundTile, findsOneWidget);

      await tester.ensureVisible(playSoundTile);
      await tester.tap(playSoundTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ringing Rajini Phone...'), findsOneWidget);
      expect(find.text('Stop Ringing'), findsOneWidget);

      await tester.tap(find.text('Stop Ringing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('DeviceDetailsScreen displays warning banner when device is in Lost Mode', (WidgetTester tester) async {
      final lostDevice = testDevice.copyWith(
        isLost: true,
        lostPhoneNumber: '+91 9988776655',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeviceDetailsScreen(initialDevice: lostDevice),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('LOST MODE IS ACTIVE'), findsOneWidget);
      expect(find.textContaining('+91 9988776655'), findsOneWidget);
    });
  });
}
