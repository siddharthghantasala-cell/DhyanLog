import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/providers.dart';

/// User-modifiable app options. Currently one: whether meditations silence the
/// phone.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _muteEnabled;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission is granted on a system screen, so re-read it on return rather
    // than leaving a stale "access needed" warning on display.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await ref.read(mutePreferenceProvider).isEnabled();
    final granted =
        await ref.read(notificationMuteServiceProvider).hasPermission();
    if (!mounted) return;
    setState(() {
      _muteEnabled = enabled;
      _hasPermission = granted;
    });
  }

  Future<void> _setMuteEnabled(bool value) async {
    setState(() => _muteEnabled = value);
    await ref.read(mutePreferenceProvider).setEnabled(value);
    ref.invalidate(muteEnabledProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final supported = ref.read(notificationMuteServiceProvider).isSupported;
    final enabled = _muteEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SwitchListTile(
              value: supported && (enabled ?? false),
              // A toggle that cannot do anything is worse than no toggle: on
              // iOS this stays off and explains why.
              onChanged:
                  supported && enabled != null ? _setMuteEnabled : null,
              title: Text(l10n.settingsMuteTitle),
              subtitle: Text(
                supported ? l10n.settingsMuteBody : l10n.settingsMuteUnsupported,
              ),
              isThreeLine: true,
              secondary: const Icon(Icons.notifications_off),
            ),
            if (supported && (enabled ?? false) && !_hasPermission)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(l10n.settingsMutePermissionNeeded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref
                              .read(meditationMuteControllerProvider)
                              .requestPermission(),
                          child: Text(l10n.settingsMuteGrantAccess),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
