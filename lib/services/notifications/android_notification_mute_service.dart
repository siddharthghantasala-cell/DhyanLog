import 'package:flutter/services.dart';

import 'notification_mute_service.dart';

/// Android implementation, backed by `NotificationMutePlugin` on the Kotlin side
/// (see android/.../NotificationMutePlugin.kt).
///
/// The native side owns the "what filter was in effect before we muted" memory
/// and persists it, so an unmute still restores correctly after the app process
/// has been killed and relaunched.
class AndroidNotificationMuteService implements NotificationMuteService {
  AndroidNotificationMuteService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName =
      'org.heartfulness.dhyanlog/notification_mute';

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasPermission() async {
    return await _invoke<bool>('hasPermission') ?? false;
  }

  @override
  Future<void> openPermissionSettings() => _invoke<void>('openSettings');

  @override
  Future<bool> mute() async => await _invoke<bool>('mute') ?? false;

  @override
  Future<void> unmute() => _invoke<void>('unmute');

  /// Platform failures here are never worth breaking a meditation over: a device
  /// that refuses to silence should leave the user meditating, not staring at an
  /// error. Swallow and report "not muted".
  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
