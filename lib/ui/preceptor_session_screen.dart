import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meditation_session.dart';
import '../state/providers.dart';

/// Live session control for the preceptor:
///   collecting -> [End Attendance] -> [Start Meditation] -> [Stop Meditation]
/// Stop is the single flush that finalizes the session.
class PreceptorSessionScreen extends ConsumerStatefulWidget {
  const PreceptorSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<PreceptorSessionScreen> createState() =>
      _PreceptorSessionScreenState();
}

class _PreceptorSessionScreenState
    extends ConsumerState<PreceptorSessionScreen> {
  bool _attendanceClosed = false;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Drives the live meditation-duration display.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(attendanceServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: SafeArea(
        child: StreamBuilder<MeditationSession>(
          stream: service.watchSession(widget.sessionId),
          builder: (context, snapshot) {
            final session = snapshot.data;
            if (session == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusChip(status: session.status),
                  const SizedBox(height: 16),
                  Text('Attendees', textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${session.attendeeCount}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (session.status == SessionStatus.meditating)
                    Text(
                      'Meditating for ${_elapsed(session.meditationStartAt)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 24),
                  if (session.status != SessionStatus.ended)
                    _JoinInfo(code: session.shortCode, qr: session.qrPayload),
                  const Spacer(),
                  ..._actions(context, service, session),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    service,
    MeditationSession session,
  ) {
    final id = widget.sessionId;
    switch (session.status) {
      case SessionStatus.collecting:
        if (!_attendanceClosed) {
          return [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await service.endAttendance(id);
                        if (mounted) setState(() => _attendanceClosed = true);
                      }),
              icon: const Icon(Icons.lock_clock),
              label: const Text('End Attendance'),
            ),
          ];
        }
        return [
          FilledButton.icon(
            onPressed:
                _busy ? null : () => _run(() => service.meditationStart(id)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Meditation'),
          ),
        ];
      case SessionStatus.meditating:
        return [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final done = await service.meditationStop(id);
                      if (!mounted) return;
                      _showSummary(done);
                    }),
            icon: const Icon(Icons.stop),
            label: const Text('Stop Meditation'),
          ),
        ];
      case SessionStatus.ended:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ];
    }
  }

  void _showSummary(MeditationSession s) {
    final mins = s.meditationEndAt != null && s.meditationStartAt != null
        ? s.meditationEndAt!.difference(s.meditationStartAt!).inMinutes
        : 0;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session saved'),
        content: Text(
          'Finalized one record:\n'
          '• ${s.attendeeCount} attendees\n'
          '• $mins min meditation\n'
          '(written as a single row — the only DB write)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _elapsed(DateTime? start) {
    if (start == null) return '0:00';
    final d = DateTime.now().difference(start);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SessionStatus.collecting => ('Collecting attendance', Colors.blue),
      SessionStatus.meditating => ('Meditation in progress', Colors.green),
      SessionStatus.ended => ('Ended', Colors.grey),
    };
    return Center(
      child: Chip(
        avatar: CircleAvatar(backgroundColor: color, radius: 6),
        label: Text(label),
      ),
    );
  }
}

class _JoinInfo extends StatelessWidget {
  const _JoinInfo({required this.code, required this.qr});

  final String code;
  final String qr;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Abhyasis join with this code'),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy join link'),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: qr)),
            ),
            Text(
              qr,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
