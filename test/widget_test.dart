import 'package:dhyanlog/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DhyanLogApp()));
    await tester.pumpAndSettle();

    expect(find.text('DhyanLog'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
