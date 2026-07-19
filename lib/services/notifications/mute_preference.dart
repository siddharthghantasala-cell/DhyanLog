import 'package:shared_preferences/shared_preferences.dart';

/// The user's "silence my phone while I meditate" setting, plus the bookkeeping
/// that lets us undo a mute we never got to undo cleanly.
///
/// Defaults to ON: it is the behaviour someone installing a meditation app
/// expects, it is reversible in one tap, and it cannot take effect at all until
/// they separately grant DND access at the system level.
class MutePreference {
  MutePreference({
    this.enabledKey = 'mute_during_meditation_v1',
    this.activeSinceKey = 'mute_active_since_v1',
  });

  final String enabledKey;
  final String activeSinceKey;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
  }

  /// Record that we silenced the device, so a mute outliving its meditation can
  /// be detected and undone on the next launch. See [activeSince].
  Future<void> markMuted(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(activeSinceKey, at.millisecondsSinceEpoch);
  }

  Future<void> clearMuted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeSinceKey);
  }

  /// When the outstanding mute began, or null if we believe nothing is muted.
  Future<DateTime?> activeSince() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(activeSinceKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
