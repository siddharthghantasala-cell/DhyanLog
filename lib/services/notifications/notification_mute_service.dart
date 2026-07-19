/// Silencing the device for the duration of a meditation.
///
/// PLATFORM REALITY: only Android can do this. It exposes Do Not Disturb to apps
/// through `NotificationManager.setInterruptionFilter`, gated behind a one-time
/// "DND access" grant the user makes in system settings. iOS has **no public API
/// for Focus/Do Not Disturb** — an app cannot silence the device, so the iOS
/// implementation reports [isSupported] false and the UI falls back to asking the
/// user to turn on Focus themselves.
///
/// Implementations must be safe to call redundantly: [mute] twice, or [unmute]
/// without a preceding [mute], must not throw.
abstract class NotificationMuteService {
  /// Whether this platform can silence notifications at all. False on iOS/web —
  /// callers should show manual guidance instead of a broken toggle.
  bool get isSupported;

  /// Whether the user has granted DND access. Always false when [isSupported]
  /// is false.
  Future<bool> hasPermission();

  /// Send the user to the system screen where DND access is granted. Returns
  /// once the intent is fired, not once the user decides — re-check
  /// [hasPermission] when the app resumes.
  Future<void> openPermissionSettings();

  /// Silence notifications, remembering the filter that was already in effect so
  /// [unmute] can restore it (a user who was *already* in DND stays in DND).
  /// Returns true if the device is now silenced.
  Future<bool> mute();

  /// Restore whatever notification filter was in effect before [mute].
  Future<void> unmute();
}

/// The no-op used on iOS, web, desktop and in tests: reports unsupported and
/// does nothing, so calling code needs no platform branches of its own.
class UnsupportedNotificationMuteService implements NotificationMuteService {
  const UnsupportedNotificationMuteService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<bool> mute() async => false;

  @override
  Future<void> unmute() async {}
}
