import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';

class DhyanLogApp extends ConsumerWidget {
  const DhyanLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final me = auth.valueOrNull?.participant;
    final seed = me == null ? AppTheme.neutralSeed : AppTheme.seedForRole(me.role);

    final Widget home;
    if (!ref.watch(signInConfiguredProvider)) {
      // Built without the sign-in key. Say so instead of showing a login form
      // that cannot work — the previous behaviour here was to fall back to fake
      // local data, which shipped to Play Store internal testing unnoticed.
      home = const _MisconfiguredScreen();
    } else if (auth.isLoading) {
      // Restoring a persisted session — avoid a flash of the login screen.
      home = const _SplashScreen();
    } else {
      home = me == null ? const LoginScreen() : const HomeScreen();
    }

    return MaterialApp(
      title: 'DhyanLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: ThemeMode.system, // follows the device's light/dark setting
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}

/// Shown when [signInConfiguredProvider] is false: the build is unusable, so it
/// fails here rather than at the first tap on a login button.
class _MisconfiguredScreen extends StatelessWidget {
  const _MisconfiguredScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_circle_outlined,
                      size: 64, color: scheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.loginNotConfiguredTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.loginNotConfiguredBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
