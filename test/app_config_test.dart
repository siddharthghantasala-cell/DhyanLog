import 'package:dhyanlog/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// These run with no --dart-define at all, which is exactly the case that used to
/// ship a fake-data build to the Play Store: the app fell back to the in-memory
/// mock and only a red login banner said so.
void main() {
  group('a build with no dart-defines', () {
    test('still targets the real backend', () {
      expect(AppConfig.useRealBackend, isTrue);
      expect(AppConfig.supabaseUrl, startsWith('https://'));
      expect(AppConfig.apiBaseUrl, endsWith('/functions/v1/api'));
    });

    test('ships one-step Heartfulness ID sign-in', () {
      expect(AppConfig.useIdSignIn, isTrue);
    });

    test('carries no sign-in key, and knows it', () {
      // The secret is never committed (public repo), so an unconfigured build
      // must report itself rather than present a login form that cannot work.
      expect(AppConfig.devAuthSecret, isEmpty);
      expect(AppConfig.isSignInConfigured, isFalse);
      expect(AppConfig.devAuth, isFalse);
    });
  });
}
