import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attend_result.dart';
import '../state/providers.dart';

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
    setState(() => _loading = true);
    final service = ref.read(attendanceServiceProvider);
    final result = await service.attendByLocation(
      heartfulnessId: _myId,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  Future<void> _tryCode([String? code]) async {
    final value = (code ?? _codeController.text).trim();
    if (value.isEmpty) return;
    setState(() => _loading = true);
    final service = ref.read(attendanceServiceProvider);
    final result =
        await service.attendByCode(heartfulnessId: _myId, codeOrSessionId: value);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Give Attendance')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildResult(context),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    if (result.isSuccess) {
      final joinedNew = result.outcome == AttendOutcome.joined;
      return _Centered(
        icon: Icons.check_circle,
        color: Colors.green,
        title: joinedNew ? 'Attendance recorded' : 'Already recorded',
        message: joinedNew
            ? 'You have been added to this session.'
            : 'You were already in this session.',
        action: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
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
          title: ambiguous
              ? 'Multiple sessions nearby'
              : 'No session found nearby',
          message: ambiguous
              ? 'We could not tell which session you are in. Enter the code '
                  'shown by your preceptor.'
              : 'Enter the code shown by your preceptor, or scan their QR.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Session code',
            hintText: 'e.g. K7M2PQ',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin),
          ),
          onSubmitted: (v) => _tryCode(v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _tryCode(),
          child: const Text('Join with code'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _tryGps,
          icon: const Icon(Icons.my_location),
          label: const Text('Retry GPS'),
        ),
        if (ambiguous) ...[
          const SizedBox(height: 24),
          const Text('Sessions detected near you:'),
          for (final c in result.candidates)
            Card(
              child: ListTile(
                title: Text('Code ${c.shortCode}'),
                subtitle: Text('${c.attendeeCount} attending'),
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
