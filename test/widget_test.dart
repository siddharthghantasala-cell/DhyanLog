import 'package:dhyanlog/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DhyanLogApp()));
    await tester.pumpAndSettle();

    expect(find.text('DhyanLog'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('two-step OTP login signs an abhyasi into home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DhyanLogApp()));
    await tester.pumpAndSettle();

    // Step 1: enter Heartfulness ID and request a code.
    await tester.enterText(find.byType(TextField), 'HFN-ABHY-001');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    // Step 2: the verify step shows the masked destination.
    expect(find.textContaining('@example.org'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // Landed on the abhyasi home screen.
    expect(find.text('Abhyasi'), findsOneWidget);
  });
}
