import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth/auth_service.dart';
import '../state/providers.dart';

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
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter your Heartfulness ID');
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
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code you received');
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
      _showError('Something went wrong. Please try again.');
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
    final onChallenge = _challenge != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.self_improvement, size: 96, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'DhyanLog',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Meditation attendance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                if (!onChallenge) ..._buildIdStep(context) else ..._buildCodeStep(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIdStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      TextField(
        controller: _idController,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _sendCode(),
        decoration: InputDecoration(
          labelText: 'Heartfulness ID',
          hintText: 'e.g. HFN-ABHY-001',
          border: const OutlineInputBorder(),
          errorText: _error,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _sendCode,
        child: _loading ? const _Spinner() : const Text('Send code'),
      ),
      const SizedBox(height: 12),
      Text(
        'We send a one-time code to the email or phone on your Heartfulness '
        'record. Try a seeded ID such as HFN-PREC-001 (preceptor) or '
        'HFN-ABHY-001 (abhyasi).',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    ];
  }

  List<Widget> _buildCodeStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      Text(
        'Enter the 6-digit code sent to ${_challenge!.maskedDestination}.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _codeController,
        textInputAction: TextInputAction.go,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _verify(),
        decoration: InputDecoration(
          labelText: 'Code',
          hintText: '123456',
          border: const OutlineInputBorder(),
          errorText: _error,
          counterText: '',
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _verify,
        child: _loading ? const _Spinner() : const Text('Verify'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _loading ? null : _changeId,
        child: const Text('Use a different ID'),
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
