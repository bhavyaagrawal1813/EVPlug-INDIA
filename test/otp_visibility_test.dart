import 'package:evplug_new/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entered OTP digits are visible in the boxes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: OTPPage(
            verificationId: 'test-verification-id',
            phoneNumber: '+919876543210',
          ),
        ),
      ),
    );

    // The real input field is visually hidden, but it still
    // receives text, paste and SMS autofill.
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();

    // Every entered digit must be visible in its box.
    for (final digit in ['1', '2', '3', '4', '5']) {
      expect(find.text(digit), findsOneWidget);
    }

    // The sixth box is still empty.
    expect(find.text('6'), findsNothing);
  });

  testWidgets('non-digit characters are stripped from the OTP',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: OTPPage(
            verificationId: 'test-verification-id',
            phoneNumber: '+919876543210',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1a2b3');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsNothing);
  });
}
