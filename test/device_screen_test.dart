import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/core/utils/app_routes.dart';
import 'package:traceup/models/device_model.dart';
import 'package:traceup/screens/devices/device_list_screen.dart';
import 'package:traceup/screens/devices/device_details_screen.dart';
import 'package:traceup/screens/devices/add_device_screen.dart';

void main() {
  testWidgets('DeviceListScreen displays filter chips, search input, and device cards', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DeviceListScreen(),
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );

    // Allow mock fetch timer to resolve
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My Devices'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('All ('), findsOneWidget);
    expect(find.textContaining('Online ('), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Add Device'), findsOneWidget);
    expect(find.text('Rajini Phone'), findsOneWidget);
  });

  testWidgets('DeviceDetailsScreen renders device details, battery level, and operations', (WidgetTester tester) async {
    final testDevice = DeviceModel(
      id: 101,
      name: 'Rajini Phone',
      deviceType: 'Android',
      isOnline: true,
      batteryLevel: 72,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeviceDetailsScreen(initialDevice: testDevice),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rajini Phone'), findsWidgets);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Locate on Map'), findsOneWidget);
    expect(find.text('Play Sound'), findsOneWidget);
    expect(find.text('Lost Mode'), findsOneWidget);
    expect(find.text('Remove This Device'), findsOneWidget);
  });

  testWidgets('AddDeviceScreen validates empty name and registers device', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AddDeviceScreen(),
      ),
    );

    expect(find.text('Add New Device'), findsOneWidget);
    expect(find.text('Register Device'), findsOneWidget);

    // Try submitting without name
    await tester.tap(find.text('Register Device'));
    await tester.pump();

    expect(find.text('Please enter a device name'), findsOneWidget);

    // Enter valid name and select Tablet
    await tester.enterText(find.byType(TextFormField), 'Office Tablet');
    await tester.tap(find.text('Tablet'));
    await tester.pump();

    await tester.tap(find.text('Register Device'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
