import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only stand up Supabase when a real backend is configured; with no
  // --dart-define the app runs entirely on the in-memory mock (incl. mock auth).
  if (AppConfig.useRealBackend) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Our configured value is the legacy anon JWT, which this field accepts.
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  void start() => runApp(const ProviderScope(child: DhyanLogApp()));

  // With a DSN configured, run inside Sentry so uncaught Flutter + Dart errors
  // are reported automatically; otherwise just start (telemetry is a no-op).
  if (AppConfig.hasSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = AppConfig.environment;
        options.tracesSampleRate = 0.2;
      },
      appRunner: start,
    );
  } else {
    start();
  }
}
