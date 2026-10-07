import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traceup/core/theme/app_theme.dart';
import 'package:traceup/core/utils/app_routes.dart';
import 'package:traceup/screens/auth/login_screen.dart';
import 'package:traceup/screens/auth/register_screen.dart';

void main() {
  testWidgets('LoginScreen renders inputs and responds to validation', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );

    // Verify fields
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);

    // Clear email and submit to test validation
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders full registration form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RegisterScreen(),
        routes: AppRoutes.routes,
      ),
    );

    // Verify fields: Name, Email, Password, Confirm Password
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
