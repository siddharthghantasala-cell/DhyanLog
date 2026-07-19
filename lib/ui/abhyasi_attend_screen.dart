import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/attend_result.dart';
import '../models/pending_attend.dart';
import '../services/http/api_client.dart';
import '../state/providers.dart';
import 'error_presentation.dart';
import 'meditation_in_progress_screen.dart';

/// Abhyasi "give attendance" flow: try GPS match first, fall back to a typed
/// short code / scanned link when the match is ambiguous or empty.
class AbhyasiAttendScreen extends ConsumerStatefulWidget {
  const AbhyasiAttendScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  ConsumerState<AbhyasiAttendScreen> createState() =>
      _AbhyasiAttendScreenState();
}

class _AbhyasiAttendScreenState extends ConsumerState<AbhyasiAttendScreen> {
  final _codeController = TextEditingController();
  bool _loading = true;
  AttendResult? _result;
  Object? _error;
  bool _queuedOffline = false;

  /// Re-run whichever attempt the user is on (GPS, or the last typed code).
  late VoidCallback _lastAttempt = _tryGps;

  @override
  void initState() {
    super.initState();
    _tryGps();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _myId => ref.read(currentParticipantProvider)!.heartfulnessId;

  Future<void> _tryGps() async {
    _lastAttempt = _tryGps;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(attendanceServiceProvider).attendByLocation(
            heartfulnessId: _myId,
            latitude: widget.latitude,
            longitude: widget.longitude,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = result;
      });
    } on NetworkException {
      await _queueOffline(PendingAttend(
        id: _newId(),
        heartfulnessId: _myId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        queuedAt: DateTime.now(),
      ));
    } catch (e) {
      _onError(e);
    }
  }

  Future<void> _tryCode([String? code]) async {
    final value = (code ?? _codeController.text).trim();
    if (value.isEmpty) return;
    _lastAttempt = () => _tryCode(value);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(attendanceServiceProvider).attendByCode(
            heartfulnessId: _myId,
            codeOrSessionId: value,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = result;
      });
    } on NetworkException {
      await _queueOffline(PendingAttend(
        id: _newId(),
        heartfulnessId: _myId,
        code: value,
        queuedAt: DateTime.now(),
      ));
    } catch (e) {
      _onError(e);
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_myId.hashCode}';

  /// Offline: hold the attempt locally; it records automatically when back online.
  Future<void> _queueOffline(PendingAttend item) async {
    await ref.read(attendQueueProvider).enqueue(item);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _queuedOffline = true;
    });
  }

  void _onError(Object error) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (isAuthError(error)) {
      ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.homeGiveAttendance)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _queuedOffline
                  ? _buildQueued(context)
                  : _error != null
                      ? ErrorRetry(error: _error!, onRetry: _lastAttempt)
                      : _buildResult(context),
        ),
      ),
    );
  }

  Widget _buildQueued(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Centered(
      icon: Icons.cloud_off,
      color: Colors.blueGrey,
      title: l10n.attendSavedOfflineTitle,
      message: l10n.attendSavedOfflineMessage,
      action: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonDone),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    if (result.isSuccess) {
      final joinedNew = result.outcome == AttendOutcome.joined;
      final session = result.session;
      return _Centered(
        icon: Icons.check_circle,
        color: Colors.green,
        title: joinedNew ? l10n.attendRecordedTitle : l10n.attendAlreadyTitle,
        message: joinedNew
            ? l10n.attendRecordedMessage
            : l10n.attendAlreadyMessage,
        // Hand off to the meditation screen, which watches the session and
        // silences the phone once the preceptor begins. Replaces this route so
        // "back" from there returns home, not to a stale result.
        action: FilledButton(
          onPressed: session == null
              ? () => Navigator.of(context).pop()
              : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MeditationInProgressScreen(sessionId: session.id),
                    ),
                  ),
          child: Text(session == null ? l10n.commonDone : l10n.attendContinue),
        ),
      );
    }

    // Ambiguous or not found -> offer code fallback (and candidate list if any).
    final ambiguous = result.outcome == AttendOutcome.ambiguous;
    return ListView(
      children: [
        _Centered.inline(
          icon: ambiguous ? Icons.help_outline : Icons.location_off,
          color: Colors.orange,
          title: ambiguous ? l10n.attendMultipleTitle : l10n.attendNoneTitle,
          message:
              ambiguous ? l10n.attendMultipleMessage : l10n.attendNoneMessage,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: l10n.attendCodeLabel,
            hintText: l10n.attendCodeHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.pin),
          ),
          onSubmitted: (v) => _tryCode(v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _tryCode(),
          child: Text(l10n.attendJoinWithCode),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _tryGps,
          icon: const Icon(Icons.my_location),
          label: Text(l10n.attendRetryGps),
        ),
        if (ambiguous) ...[
          const SizedBox(height: 24),
          Text(l10n.attendNearbyHeader),
          for (final c in result.candidates)
            Card(
              child: ListTile(
                title: Text(l10n.attendCandidateCode(c.shortCode)),
                subtitle: Text(l10n.attendCandidateCount(c.attendeeCount)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _tryCode(c.shortCode),
              ),
            ),
        ],
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.action,
  }) : _inline = false;

  const _Centered.inline({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  })  : action = null,
        _inline = true;

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? action;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 24),
          action!,
        ],
      ],
    );
    return _inline ? content : Center(child: content);
  }
}
