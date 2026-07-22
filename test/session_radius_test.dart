import 'package:dhyanlog/models/attend_result.dart';
import 'package:dhyanlog/models/meditation_center.dart';
import 'package:dhyanlog/models/meditation_session.dart';
import 'package:dhyanlog/services/centers/mock_centers_service.dart';
import 'package:dhyanlog/services/mock/mock_attendance_service.dart';
import 'package:dhyanlog/services/mock/seed_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chennai = SeedData.centers.firstWhere((c) => c.id == 'CTR-CHN-01');

  // ~300m north of the Chennai anchor (1 deg lat ~= 111.32km).
  final far = (
    lat: chennai.latitude + 300 / 111320,
    lng: chennai.longitude,
  );

  group('models carry type + radius', () {
    test('MeditationCenter round-trips its check radius', () {
      final c = MeditationCenter.fromJson(const {
        'id': 'CTR-X',
        'name': 'X',
        'latitude': 1.0,
        'longitude': 2.0,
        'address': 'somewhere',
        'check_radius_meters': 750,
      });
      expect(c.checkRadiusMeters, 750);
      expect(c.toJson()['check_radius_meters'], 750);
    });

    test('MeditationCenter defaults the radius when absent', () {
      final c = MeditationCenter.fromJson(const {
        'id': 'CTR-X',
        'name': 'X',
        'latitude': 1.0,
        'longitude': 2.0,
      });
      expect(c.checkRadiusMeters, 200);
    });

    test('MeditationSession round-trips type + match radius', () {
      final json = {
        'id': 's1',
        'preceptor_id': 'HFN-PREC-001',
        'center_id': 'CTR-CHN-01',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'start_attendance_at': DateTime.now().toIso8601String(),
        'meditation_start_at': null,
        'meditation_end_at': null,
        'status': 'collecting',
        'attendee_count': 0,
        'short_code': 'ABC123',
        'type': 'satsang',
        'match_radius_meters': 500,
      };
      final s = MeditationSession.fromJson(json);
      expect(s.type, SessionType.satsang);
      expect(s.matchRadiusMeters, 500);
    });

    test('MeditationSession defaults type/radius on a legacy payload', () {
      final s = MeditationSession.fromJson({
        'id': 's1',
        'preceptor_id': 'HFN-PREC-001',
        'center_id': null,
        'latitude': 13.0,
        'longitude': 80.0,
        'start_attendance_at': DateTime.now().toIso8601String(),
        'status': 'ended',
        'attendee_count': 2,
        'short_code': 'ABC123',
      });
      expect(s.type, SessionType.regular);
      expect(s.matchRadiusMeters, 30);
    });
  });

  group('mock service applies per-session radius', () {
    test('a satsang captures an attendee ~300m from the center', () async {
      final svc = MockAttendanceService();
      final session = await svc.startSession(
        preceptorId: 'HFN-PREC-001',
        centerId: chennai.id, // -> satsang, 500m radius
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      expect(session.type, SessionType.satsang);
      expect(session.matchRadiusMeters, chennai.checkRadiusMeters);

      final r = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: far.lat,
        longitude: far.lng,
      );
      expect(r.outcome, AttendOutcome.joined);
    });

    test('a regular session rejects the same ~300m-away attendee', () async {
      final svc = MockAttendanceService();
      final session = await svc.startSession(
        preceptorId: 'HFN-PREC-001', // no center -> regular, 30m radius
        latitude: chennai.latitude,
        longitude: chennai.longitude,
      );
      expect(session.type, SessionType.regular);
      expect(session.matchRadiusMeters, 30);

      final r = await svc.attendByLocation(
        heartfulnessId: 'HFN-ABHY-001',
        latitude: far.lat,
        longitude: far.lng,
      );
      expect(r.outcome, AttendOutcome.notFound);
    });
  });

  test('mock centers service exposes seeded radii', () async {
    final centers = await MockCentersService().listCenters();
    final kanha = centers.firstWhere((c) => c.id == 'CTR-KANHA');
    expect(kanha.checkRadiusMeters, 2000);
  });
}
