import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meditation_center.dart';
import '../models/participant.dart';
import '../services/mock/seed_data.dart';
import '../state/providers.dart';
import 'abhyasi_attend_screen.dart';
import 'preceptor_session_screen.dart';

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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentParticipantProvider);
    if (me == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isLeader = me.role.canLead;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLeader ? 'Preceptor' : 'Abhyasi'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(currentParticipantProvider.notifier).state = null,
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
                label: isLeader ? 'Start Attendance' : 'Give Attendance',
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
    return Column(
      children: [
        Text('Namaste, $name',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Chip(label: Text(role.name.toUpperCase())),
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
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Your location (simulated GPS)',
        prefixIcon: Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(),
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
