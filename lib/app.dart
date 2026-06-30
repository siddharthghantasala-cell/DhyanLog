import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';

class DhyanLogApp extends ConsumerWidget {
  const DhyanLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final me = auth.valueOrNull?.participant;
    final theme = me == null ? AppTheme.neutral : AppTheme.forRole(me.role);

    final Widget home;
    if (auth.isLoading) {
      // Restoring a persisted session — avoid a flash of the login screen.
      home = const _SplashScreen();
    } else {
      home = me == null ? const LoginScreen() : const HomeScreen();
    }

    return MaterialApp(
      title: 'DhyanLog',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: home,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Icon(Icons.self_improvement, size: 96, color: scheme.primary),
      ),
    );
  }
}
