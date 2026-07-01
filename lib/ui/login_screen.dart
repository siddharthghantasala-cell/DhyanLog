import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/auth/auth_service.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';

/// Two-step sign-in: enter Heartfulness ID -> receive a one-time code at the
/// contact on file -> verify. No matching member means no entry.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Non-null once a code has been sent; drives the switch to the verify step.
  OtpChallenge? _challenge;

  @override
  void dispose() {
    _idController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = l10n.loginEnterId);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(authServiceProvider).requestOtp(id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _challenge = challenge;
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(l10n.commonSomethingWrong);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = l10n.loginEnterCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On success [authStateProvider] updates and the app swaps to home; this
      // screen is torn down, so there's nothing more to do here.
      await ref.read(authServiceProvider).verifyOtp(code);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(l10n.commonSomethingWrong);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  void _changeId() {
    setState(() {
      _challenge = null;
      _codeController.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final onChallenge = _challenge != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.self_improvement, size: 96, color: scheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!onChallenge)
                    ..._buildIdStep(context, l10n)
                  else
                    ..._buildCodeStep(context, l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIdStep(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return [
      TextField(
        controller: _idController,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _sendCode(),
        decoration: InputDecoration(
          labelText: l10n.loginIdLabel,
          hintText: l10n.loginIdHint,
          border: const OutlineInputBorder(),
          errorText: _error,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _loading ? null : _sendCode,
        child: _loading ? const _Spinner() : Text(l10n.loginSendCode),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        l10n.loginHelp,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    ];
  }

  List<Widget> _buildCodeStep(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return [
      Text(
        l10n.loginCodeSentTo(_challenge!.maskedDestination),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _codeController,
        textInputAction: TextInputAction.go,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _verify(),
        decoration: InputDecoration(
          labelText: l10n.loginCodeLabel,
          hintText: '123456',
          border: const OutlineInputBorder(),
          errorText: _error,
          counterText: '',
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _loading ? null : _verify,
        child: _loading ? const _Spinner() : Text(l10n.loginVerify),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: _loading ? null : _changeId,
        child: Text(l10n.loginUseDifferentId),
      ),
    ];
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
