import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/meditation_center.dart';
import '../models/participant.dart';
import '../services/mock/seed_data.dart';
import '../state/providers.dart';
import 'abhyasi_attend_screen.dart';
import 'error_presentation.dart';
import 'preceptor_session_screen.dart';

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
  // Simulated device location for the mock phase: pick a center. In production
  // this is replaced by real GPS.
  late MeditationCenter _location = SeedData.centers.first;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Opportunistically record any attendance that was queued while offline.
    // Fire-and-forget; failures just leave items queued for next time.
    Future(() => ref.read(attendQueueProvider).flush()).ignore();
  }

  Future<void> _onPrimaryAction(Participant me) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (me.role.canLead) {
        final service = ref.read(attendanceServiceProvider);
        final session = await service.startSession(
          preceptorId: me.heartfulnessId,
          centerId: _location.id,
          latitude: _location.latitude,
          longitude: _location.longitude,
        );
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PreceptorSessionScreen(sessionId: session.id),
        ));
      } else {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AbhyasiAttendScreen(
            latitude: _location.latitude,
            longitude: _location.longitude,
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
                case 'logout':
                  ref.read(authServiceProvider).signOut();
                case 'delete':
                  _confirmDeleteAccount();
              }
            },
            itemBuilder: (context) => [
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
                value: _location,
                onChanged: (c) => setState(() => _location = c),
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
  const _LocationPicker({required this.value, required this.onChanged});

  final MeditationCenter value;
  final ValueChanged<MeditationCenter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.homeLocationLabel,
        prefixIcon: const Icon(Icons.location_on_outlined),
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MeditationCenter>(
          isExpanded: true,
          value: value,
          items: [
            for (final c in SeedData.centers)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: (c) => c == null ? null : onChanged(c),
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
