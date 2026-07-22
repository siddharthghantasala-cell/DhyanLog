import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../models/meditation_center.dart';
import '../models/participant.dart';
import '../services/mock/seed_data.dart';
import '../state/providers.dart';
import 'abhyasi_attend_screen.dart';
import 'error_presentation.dart';
import 'history_screen.dart';
import 'preceptor_session_screen.dart';
import 'settings_screen.dart';

/// Localized display name for a role.
String roleLabel(AppLocalizations l10n, ParticipantRole role) {
  return switch (role) {
    ParticipantRole.preceptor => l10n.rolePreceptor,
    ParticipantRole.abhyasi => l10n.roleAbhyasi,
    ParticipantRole.master => l10n.roleMaster,
  };
}

/// Landing screen after login. One large central action button whose meaning
/// depends on the participant's role.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Where actions report from: a picked center, or null = the device's real
  // GPS position (resolved at button press). Real backend defaults to GPS;
  // mock keeps the simulated center picker so seeded sessions still match.
  MeditationCenter? _center =
      AppConfig.useRealBackend ? null : SeedData.centers.first;
  bool _busy = false;

  /// The coordinates (and optional center tag) to act from. A picked center is
  /// immediate; GPS requests permission and reads a fresh fix, throwing a
  /// LocationException the caller surfaces via showActionError.
  Future<({String? centerId, double latitude, double longitude})>
      _resolveLocation() async {
    final center = _center;
    if (center != null) {
      return (
        centerId: center.id,
        latitude: center.latitude,
        longitude: center.longitude,
      );
    }
    final position =
        await ref.read(locationServiceProvider).currentPosition();
    return (
      centerId: null,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    // Opportunistically record any attendance that was queued while offline.
    // Fire-and-forget; failures just leave items queued for next time.
    Future(() => ref.read(attendQueueProvider).flush()).ignore();
    // If a previous run was killed mid-meditation it may have left the phone on
    // Do Not Disturb. Restore it now — reaching home means no meditation of ours
    // is running.
    Future(() => ref.read(meditationMuteControllerProvider).reconcile())
        .ignore();
  }

  Future<void> _onPrimaryAction(Participant me) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final location = await _resolveLocation();
      if (me.role.canLead) {
        final service = ref.read(attendanceServiceProvider);
        final session = await service.startSession(
          preceptorId: me.heartfulnessId,
          centerId: location.centerId,
          latitude: location.latitude,
          longitude: location.longitude,
        );
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PreceptorSessionScreen(sessionId: session.id),
        ));
      } else {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AbhyasiAttendScreen(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        ));
      }
    } catch (e) {
      if (mounted) showActionError(ref, context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirm, then permanently delete the app login. Org-owned membership and
  /// attendance are left intact (see AuthService.deleteAccount). On success the
  /// auth stream flips to signed-out and routing returns to the login screen.
  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(authServiceProvider).deleteAccount();
    } catch (e) {
      if (mounted) showActionError(ref, context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentParticipantProvider);
    if (me == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isLeader = me.role.canLead;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLeader ? l10n.rolePreceptor : l10n.roleAbhyasi),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'history':
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ));
                case 'settings':
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ));
                case 'logout':
                  ref.read(authServiceProvider).signOut();
                case 'delete':
                  _confirmDeleteAccount();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.homeHistory),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(l10n.homeSettings),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.homeLogOut),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: scheme.error),
                  title: Text(
                    l10n.homeDeleteAccount,
                    style: TextStyle(color: scheme.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _Greeting(name: me.name, role: me.role),
              const SizedBox(height: 16),
              _LocationPicker(
                value: _center,
                centers:
                    ref.watch(centersProvider).valueOrNull ?? SeedData.centers,
                onChanged: (c) => setState(() => _center = c),
              ),
              const Spacer(),
              _BigButton(
                label: isLeader ? l10n.homeStartAttendance : l10n.homeGiveAttendance,
                color: scheme.primary,
                onColor: scheme.onPrimary,
                busy: _busy,
                onTap: () => _onPrimaryAction(me),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.role});

  final String name;
  final ParticipantRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(l10n.homeGreeting(name),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Chip(label: Text(roleLabel(l10n, role).toUpperCase())),
      ],
    );
  }
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({
    required this.value,
    required this.centers,
    required this.onChanged,
  });

  /// The picked center, or null for the device's real GPS position.
  final MeditationCenter? value;

  /// Centers to offer (a satsang venue). Server-backed; falls back to seeds.
  final List<MeditationCenter> centers;
  final ValueChanged<MeditationCenter?> onChanged;

  // DropdownButton renders its hint for a null value, so GPS gets a string
  // sentinel and centers are keyed by id.
  static const String _gps = '__gps__';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.homeLocationLabel,
        prefixIcon: Icon(
          value == null ? Icons.my_location : Icons.location_on_outlined,
        ),
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value?.id ?? _gps,
          items: [
            DropdownMenuItem(value: _gps, child: Text(l10n.homeLocationGps)),
            for (final c in centers)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (id) => onChanged(
            id == null || id == _gps
                ? null
                : centers.firstWhere((c) => c.id == id),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.color,
    required this.onColor,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color onColor;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  height: 48,
                  width: 48,
                  child: CircularProgressIndicator(color: onColor),
                )
              else
                Icon(Icons.self_improvement, size: 88, color: onColor),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
