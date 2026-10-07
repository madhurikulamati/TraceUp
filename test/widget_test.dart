import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/main.dart';
import 'package:traceup/core/constants/app_strings.dart';

void main() {
  testWidgets('TraceUp initial launch smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TraceUpApp());

    // Verify that Splash screen loads with app name.
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);

    // Let splash timer finish and transition to Login
    await tester.pumpAndSettle();

    // Verify that Login screen is rendered
    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.loginButton), findsOneWidget);
  });
}
