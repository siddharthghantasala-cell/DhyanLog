import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Login by Heartfulness ID. No matching record => no entry.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _controller.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter your Heartfulness ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(participantRepositoryProvider);
    final participant = await repo.findByHeartfulnessId(id);
    if (!mounted) return;
    if (participant == null) {
      setState(() {
        _loading = false;
        _error = 'No Heartfulness member found for "$id".';
      });
      return;
    }
    ref.read(currentParticipantProvider.notifier).state = participant;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _login(),
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
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Heartfulness ID means no sign-up. Try a seeded ID such as '
                  'HFN-PREC-001 (preceptor) or HFN-ABHY-001 (abhyasi).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
