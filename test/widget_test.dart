import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/main.dart';
import 'package:traceup/core/constants/app_strings.dart';
import 'package:traceup/storage/token_storage.dart';
import 'package:traceup/services/auth_service.dart';

void main() {
  testWidgets('TraceUp initial launch navigates to Login when unauthenticated', (WidgetTester tester) async {
    // Ensure clean unauthenticated state
    await TokenStorage().clearAll();
    await AuthService().logout();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const TraceUpApp());

    // Verify that Splash screen loads with app name.
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);

    // Advance past splash delay (1500ms) and route transition
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that Login screen is rendered
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.loginButton), findsOneWidget);
  });

  testWidgets('TraceUp initial launch navigates to Home when already authenticated', (WidgetTester tester) async {
    // Seed authenticated session
    await TokenStorage().saveTokens(
      accessToken: 'valid_mock_token',
      refreshToken: 'valid_refresh_token',
    );

    // Build app
    await tester.pumpWidget(const TraceUpApp());

    // Advance past splash delay and route transition
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));

    // Allow HomeScreen data fetch to resolve
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that Home screen is rendered
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.myDevices), findsOneWidget);
  });
}
