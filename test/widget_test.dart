import 'package:dhyanlog/app.dart';
import 'package:dhyanlog/services/auth/mock_auth_service.dart';
import 'package:dhyanlog/services/mock/mock_participant_repository.dart';
import 'package:dhyanlog/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real backend is baked into [AppConfig] so no build can ship against the
/// mock (see `lib/config/app_config.dart`), which means these tests must supply
/// their own auth rather than inheriting a mock from the build config.
Widget _app(SignInMode mode) {
  return ProviderScope(
    overrides: [
      signInModeProvider.overrideWithValue(mode),
      signInConfiguredProvider.overrideWithValue(true),
      authServiceProvider
          .overrideWith((ref) => MockAuthService(MockParticipantRepository())),
    ],
    child: const DhyanLogApp(),
  );
}

void main() {
  testWidgets('boots to one-step Heartfulness ID sign-in', (tester) async {
    await tester.pumpWidget(_app(SignInMode.id));
    await tester.pumpAndSettle();

    expect(find.text('DhyanLog'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // The dormant OTP flow must not be reachable from the shipping build.
    expect(find.text('Send code'), findsNothing);
  });

  testWidgets('id sign-in signs an abhyasi into home', (tester) async {
    await tester.pumpWidget(_app(SignInMode.id));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'HFN-ABHY-001');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Abhyasi'), findsOneWidget);
  });

  testWidgets('a build with no sign-in key says so instead of showing a login',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signInConfiguredProvider.overrideWithValue(false),
          authServiceProvider.overrideWith(
            (ref) => MockAuthService(MockParticipantRepository()),
          ),
        ],
        child: const DhyanLogApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("This build can't sign in"), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('otp mode still runs the two-step flow', (tester) async {
    await tester.pumpWidget(_app(SignInMode.otp));
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
