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
    final me = ref.watch(currentParticipantProvider);
    final theme = me == null ? AppTheme.neutral : AppTheme.forRole(me.role);
    return MaterialApp(
      title: 'DhyanLog',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: me == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
