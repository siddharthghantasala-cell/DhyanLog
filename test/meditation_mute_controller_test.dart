import 'package:dhyanlog/services/notifications/meditation_mute_controller.dart';
import 'package:dhyanlog/services/notifications/mute_preference.dart';
import 'package:dhyanlog/services/notifications/notification_mute_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what was asked of the platform, and can pretend to be an
/// unsupported platform or one missing the DND grant.
class FakeMuteService implements NotificationMuteService {
  FakeMuteService({this.supported = true, this.permitted = true});

  final bool supported;
  bool permitted;

  int muteCalls = 0;
  int unmuteCalls = 0;
  int settingsCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> openPermissionSettings() async => settingsCalls++;

  @override
  Future<bool> mute() async {
    muteCalls++;
    return permitted;
  }

  @override
  Future<void> unmute() async => unmuteCalls++;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MeditationMuteController build(
    FakeMuteService service, {
    Duration maxDuration = const Duration(hours: 3),
  }) {
    return MeditationMuteController(
      service: service,
      preference: MutePreference(),
      maxDuration: maxDuration,
    );
  }

  group('MeditationMuteController.engage', () {
    test('silences the device by default', () async {
      final service = FakeMuteService();
      expect(await build(service).engage(), MuteStatus.muted);
      expect(service.muteCalls, 1);
    });

    test('does nothing when the user turned the setting off', () async {
      final service = FakeMuteService();
      await MutePreference().setEnabled(false);

      expect(await build(service).engage(), MuteStatus.disabledByUser);
      expect(service.muteCalls, 0);
    });

    test('reports unsupported without touching the platform', () async {
      final service = FakeMuteService(supported: false);
      expect(await build(service).engage(), MuteStatus.unsupported);
      expect(service.muteCalls, 0);
    });

    test('reports missing DND access', () async {
      final service = FakeMuteService(permitted: false);
      expect(await build(service).engage(), MuteStatus.permissionRequired);
    });

    test('records the mute so a later reconcile can undo it', () async {
      final preference = MutePreference();
      await MeditationMuteController(
        service: FakeMuteService(),
        preference: preference,
      ).engage();

      expect(await preference.activeSince(), isNotNull);
    });
  });

  group('MeditationMuteController.release', () {
    test('restores notifications and clears the record', () async {
      final service = FakeMuteService();
      final preference = MutePreference();
      final controller = MeditationMuteController(
        service: service,
        preference: preference,
      );

      await controller.engage();
      await controller.release();

      expect(service.unmuteCalls, 1);
      expect(await preference.activeSince(), isNull);
      expect(controller.isMuted, isFalse);
    });

    test('is safe when nothing was muted', () async {
      final service = FakeMuteService();
      await build(service).release();
      expect(service.unmuteCalls, 1); // idempotent at the platform layer
    });
  });

  group('MeditationMuteController hard cap', () {
    test('un-silences a meditation that never ends', () async {
      final service = FakeMuteService();
      final controller = build(service, maxDuration: Duration.zero);

      await controller.engage();
      // Let the zero-duration cap timer fire.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.unmuteCalls, 1);
    });
  });

  group('MeditationMuteController.reconcile', () {
    test('restores a mute stranded by a killed app', () async {
      final service = FakeMuteService();
      // Simulate a previous run that muted and never got to release.
      await MutePreference().markMuted(DateTime.now());

      await build(service).reconcile();

      expect(service.unmuteCalls, 1);
      expect(await MutePreference().activeSince(), isNull);
    });

    test('leaves the device alone when nothing was stranded', () async {
      final service = FakeMuteService();
      await build(service).reconcile();
      expect(service.unmuteCalls, 0);
    });
  });
}
