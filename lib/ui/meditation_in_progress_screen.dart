import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/meditation_session.dart';
import '../services/notifications/meditation_mute_controller.dart';
import '../state/providers.dart';
import 'error_presentation.dart';

/// The abhyasi's view of a session they have joined, from "attendance recorded"
/// through to the preceptor ending the meditation.
///
/// This screen exists because the *device* needs to know when the meditation is
/// running: the preceptor controls the lifecycle remotely, so the phone can only
/// silence itself for the right window by watching the session. Do Not Disturb
/// engages the moment the status turns to meditating and is released the moment
/// it ends — or when the user leaves this screen, whichever comes first.
class MeditationInProgressScreen extends ConsumerStatefulWidget {
  const MeditationInProgressScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<MeditationInProgressScreen> createState() =>
      _MeditationInProgressScreenState();
}

class _MeditationInProgressScreenState
    extends ConsumerState<MeditationInProgressScreen>
    with WidgetsBindingObserver {
  StreamSubscription<MeditationSession>? _subscription;
  Timer? _ticker;

  MeditationSession? _session;
  Object? _error;
  MuteStatus? _muteStatus;

  MeditationMuteController get _mute =>
      ref.read(meditationMuteControllerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watch();
    // Drives the elapsed-time readout; cheap enough to run for the whole screen.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _subscription?.cancel();
    // Leaving this screen always restores notifications, however we got here
    // (back button, error, session end). Fire-and-forget: dispose can't await,
    // and the controller's startup reconcile is the remaining safety net.
    _mute.release().ignore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have been sent to system settings to grant DND access; retry
    // the mute when they come back so they don't have to do anything else.
    if (state == AppLifecycleState.resumed &&
        _muteStatus == MuteStatus.permissionRequired &&
        _session?.status == SessionStatus.meditating) {
      _engageMute();
    }
  }

  void _watch() {
    _subscription?.cancel();
    setState(() => _error = null);
    _subscription = ref
        .read(attendanceServiceProvider)
        .watchSession(widget.sessionId)
        .listen(
          _onSession,
          onError: (Object e) {
            if (!mounted) return;
            setState(() => _error = e);
            if (isAuthError(e)) ref.read(authServiceProvider).signOut();
          },
        );
  }

  Future<void> _onSession(MeditationSession session) async {
    if (!mounted) return;
    final previous = _session;
    setState(() => _session = session);

    final started = session.status == SessionStatus.meditating &&
        previous?.status != SessionStatus.meditating;
    if (started) await _engageMute();

    if (session.status == SessionStatus.ended) {
      await _mute.release();
      if (mounted) setState(() => _muteStatus = null);
    }
  }

  Future<void> _engageMute() async {
    final status = await _mute.engage();
    if (mounted) setState(() => _muteStatus = status);
  }

  Future<void> _grantPermission() async {
    await _mute.requestPermission();
    // The user decides in system settings; didChangeAppLifecycleState retries
    // the mute when they return.
  }

  /// Leaving mid-meditation is allowed (attendance is already recorded) but is
  /// worth a confirmation, since it also un-silences the phone.
  Future<bool> _confirmLeave() async {
    if (_session?.status != SessionStatus.meditating) return true;
    final l10n = AppLocalizations.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.meditationLeaveTitle),
        content: Text(l10n.meditationLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.meditationLeave),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final ended = session?.status == SessionStatus.ended;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Captured before the await so the pop doesn't reach for a context that
        // may have been torn down while the dialog was open.
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.meditationInProgressTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error != null
                ? ErrorRetry(error: _error!, onRetry: _watch)
                : session == null
                    ? const Center(child: CircularProgressIndicator())
                    : ended
                        ? _buildEnded(context, session)
                        : _buildActive(context, session),
          ),
        ),
      ),
    );
  }

  Widget _buildActive(BuildContext context, MeditationSession session) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final meditating = session.status == SessionStatus.meditating;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.self_improvement,
          size: 96,
          color: meditating
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
        const SizedBox(height: 24),
        Text(
          meditating
              ? l10n.meditationInProgressTitle
              : l10n.meditationWaitingTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (meditating)
          Text(
            _elapsed(session.meditationStartAt),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          )
        else
          Text(l10n.meditationWaitingBody, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(
          l10n.meditationAttendees(session.attendeeCount),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        if (meditating) _MuteBanner(status: _muteStatus, onGrant: _grantPermission),
      ],
    );
  }

  Widget _buildEnded(BuildContext context, MeditationSession session) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final start = session.meditationStartAt;
    final end = session.meditationEndAt;
    final minutes =
        (start != null && end != null) ? end.difference(start).inMinutes : 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 96, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          l10n.meditationCompleteTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(l10n.meditationCompleteBody(minutes), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          l10n.meditationAttendees(session.attendeeCount),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.meditationBackHome),
        ),
      ],
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

/// Tells the user, honestly, whether their phone is actually silenced — and
/// offers the one action that can change that when it isn't.
class _MuteBanner extends StatelessWidget {
  const _MuteBanner({required this.status, required this.onGrant});

  final MuteStatus? status;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (status == null) return const SizedBox.shrink();

    final (icon, message, showGrant) = switch (status!) {
      MuteStatus.muted => (Icons.notifications_off, l10n.meditationMuted, false),
      MuteStatus.disabledByUser => (
          Icons.notifications_active,
          l10n.meditationMuteDisabled,
          false,
        ),
      MuteStatus.unsupported => (
          Icons.info_outline,
          l10n.meditationMuteUnsupported,
          false,
        ),
      MuteStatus.permissionRequired => (
          Icons.notifications_active,
          l10n.meditationMutePermission,
          true,
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            if (showGrant) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onGrant,
                child: Text(l10n.meditationMuteGrant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
