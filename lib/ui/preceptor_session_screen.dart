import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/attendee_roster.dart';
import '../models/meditation_session.dart';
import '../state/providers.dart';
import 'error_presentation.dart';

/// Live session control for the preceptor:
///   meditating (attendance open) -> [Stop Meditation]
/// Attendance stays open for the whole meditation (latecomers still count), and
/// the single Stop is the one flush that finalizes the session.
class PreceptorSessionScreen extends ConsumerStatefulWidget {
  const PreceptorSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<PreceptorSessionScreen> createState() =>
      _PreceptorSessionScreenState();
}

class _PreceptorSessionScreenState
    extends ConsumerState<PreceptorSessionScreen> {
  bool _busy = false;
  bool _ended = false;
  Timer? _ticker;
  Timer? _rosterTimer;

  /// Names of who has checked in, refreshed on its own light poll (separate from
  /// the session stream). Best-effort: a failed roster poll never breaks the
  /// screen — the authoritative count still comes from the session stream.
  AttendeeRoster _roster = AttendeeRoster.empty;

  /// The live session stream, created once (not on every ticker rebuild) so the
  /// poll loop isn't torn down and recreated each second.
  late Stream<MeditationSession> _sessionStream;

  @override
  void initState() {
    super.initState();
    _sessionStream =
        ref.read(attendanceServiceProvider).watchSession(widget.sessionId);
    // Drives the live meditation-duration display.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Names climb as people join; poll a little less often than the ticker.
    _refreshRoster();
    _rosterTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshRoster());
  }

  Future<void> _refreshRoster() async {
    if (_ended) return;
    try {
      final roster = await ref
          .read(attendanceServiceProvider)
          .sessionRoster(widget.sessionId);
      if (mounted && !_ended) setState(() => _roster = roster);
    } catch (_) {
      // Best-effort: the names list is a nice-to-have, never worth an error.
    }
  }

  void _resubscribe() {
    setState(() {
      _sessionStream =
          ref.read(attendanceServiceProvider).watchSession(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rosterTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showActionError(ref, context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(attendanceServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionTitle)),
      body: SafeArea(
        child: StreamBuilder<MeditationSession>(
          stream: _sessionStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              if (isAuthError(snapshot.error!)) {
                ref.read(authServiceProvider).signOut();
              }
              return Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorRetry(
                  error: snapshot.error!,
                  onRetry: _resubscribe,
                ),
              );
            }
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
                  Text(l10n.sessionAttendees, textAlign: TextAlign.center,
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
                      l10n.sessionMeditatingFor(
                          _elapsed(session.meditationStartAt)),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 16),
                  if (session.status != SessionStatus.ended)
                    _JoinInfo(code: session.shortCode, qr: session.qrPayload),
                  const SizedBox(height: 16),
                  Expanded(child: _AttendeeList(roster: _roster)),
                  const SizedBox(height: 16),
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
    final l10n = AppLocalizations.of(context)!;
    if (session.status == SessionStatus.ended) {
      return [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonDone),
        ),
      ];
    }
    // Live session: attendance is open and meditation is running. One action
    // ends both and flushes the single finalized record.
    return [
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: _busy
            ? null
            : () => _run(() async {
                  final done = await service.meditationStop(id);
                  _ended = true;
                  _rosterTimer?.cancel();
                  if (!mounted) return;
                  _showSummary(done);
                }),
        icon: const Icon(Icons.stop),
        label: Text(l10n.sessionStopMeditation),
      ),
    ];
  }

  void _showSummary(MeditationSession s) {
    final l10n = AppLocalizations.of(context)!;
    final mins = s.meditationEndAt != null && s.meditationStartAt != null
        ? s.meditationEndAt!.difference(s.meditationStartAt!).inMinutes
        : 0;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sessionSavedTitle),
        content: Text(l10n.sessionSavedBody(s.attendeeCount, mins)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonOk),
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

/// The live list of who has checked in, for the preceptor. Shows names while the
/// session is small enough; for a mass gathering ([AttendeeRoster.capped]) it
/// shows only a note (the count is displayed above).
class _AttendeeList extends StatelessWidget {
  const _AttendeeList({required this.roster});

  final AttendeeRoster roster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.outline,
    );

    if (roster.capped) {
      return Center(
        child: Text(l10n.sessionRosterCapped,
            textAlign: TextAlign.center, style: muted),
      );
    }
    if (roster.names.isEmpty) {
      return Center(
        child: Text(l10n.sessionNoAttendeesYet,
            textAlign: TextAlign.center, style: muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.sessionCheckedInTitle,
              style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: roster.names.length,
            itemBuilder: (context, i) => ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle,
                  size: 18, color: theme.colorScheme.primary),
              title: Text(roster.names[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      SessionStatus.collecting => (l10n.sessionStatusCollecting, Colors.blue),
      SessionStatus.meditating => (l10n.sessionStatusMeditating, Colors.green),
      SessionStatus.ended => (l10n.sessionStatusEnded, Colors.grey),
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.sessionJoinPrompt),
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
              label: Text(l10n.sessionCopyJoinLink),
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
