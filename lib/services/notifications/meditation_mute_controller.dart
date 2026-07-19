import 'dart:async';

import 'mute_preference.dart';
import 'notification_mute_service.dart';

/// Why the device is (or isn't) silenced — drives what the meditation screen
/// tells the user.
enum MuteStatus {
  /// Notifications are silenced for this meditation.
  muted,

  /// The user turned the setting off. Nothing was silenced, and that's correct.
  disabledByUser,

  /// This platform can't silence notifications at all (iOS/web). The UI should
  /// suggest turning on Focus manually.
  unsupported,

  /// Supported and wanted, but the user hasn't granted DND access yet. The UI
  /// should offer a button into system settings.
  permissionRequired,
}

/// Owns the mute lifecycle for a meditation: silence on start, restore on end,
/// and — critically — make sure a phone never gets *stranded* on silent.
///
/// Three things can strand a mute, and each has a defence:
///  1. the user leaves the screen        -> [release] from the screen's dispose
///  2. the meditation runs unbounded     -> [maxDuration] hard cap timer
///  3. the app is force-killed mid-mute  -> [reconcile] on next launch
class MeditationMuteController {
  MeditationMuteController({
    required NotificationMuteService service,
    required MutePreference preference,
    this.maxDuration = const Duration(hours: 3),
  })  : _service = service,
        _preference = preference;

  final NotificationMuteService _service;
  final MutePreference _preference;

  /// Backstop: however long the meditation claims to run, the device un-silences
  /// after this. Comfortably longer than any real sitting.
  final Duration maxDuration;

  Timer? _capTimer;

  /// Whether this controller currently believes it is holding a mute.
  bool get isMuted => _capTimer != null;

  /// Silence the device for a meditation now beginning. Safe to call twice.
  Future<MuteStatus> engage() async {
    if (!await _preference.isEnabled()) return MuteStatus.disabledByUser;
    if (!_service.isSupported) return MuteStatus.unsupported;
    if (!await _service.hasPermission()) return MuteStatus.permissionRequired;

    final muted = await _service.mute();
    if (!muted) return MuteStatus.permissionRequired;

    await _preference.markMuted(DateTime.now());
    _capTimer?.cancel();
    _capTimer = Timer(maxDuration, () {
      // Fire-and-forget: nothing is awaiting the cap, and a failure here leaves
      // the next launch's reconcile() as the remaining safety net.
      release().ignore();
    });
    return MuteStatus.muted;
  }

  /// Restore the notification state the user had before [engage]. Safe to call
  /// when nothing was muted.
  Future<void> release() async {
    _capTimer?.cancel();
    _capTimer = null;
    await _service.unmute();
    await _preference.clearMuted();
  }

  /// Called once at startup. A recorded mute with no meditation screen running
  /// means we were killed mid-session and never restored the user's settings —
  /// so restore them now rather than leaving the phone silent indefinitely.
  Future<void> reconcile() async {
    if (await _preference.activeSince() == null) return;
    await _service.unmute();
    await _preference.clearMuted();
  }

  /// Ask for DND access. The user decides in system settings, so callers should
  /// re-run [engage] when the app resumes rather than trusting a return value.
  Future<void> requestPermission() => _service.openPermissionSettings();
}
