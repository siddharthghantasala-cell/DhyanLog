import 'dart:async';

import 'package:dhyanlog/services/location/geolocator_location_service.dart';
import 'package:dhyanlog/services/location/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

GeolocatorLocationService _service({
  bool enabled = true,
  LocationPermission check = LocationPermission.whileInUse,
  LocationPermission request = LocationPermission.whileInUse,
  Future<Position> Function()? getPosition,
}) {
  return GeolocatorLocationService(
    isServiceEnabled: () async => enabled,
    checkPermission: () async => check,
    requestPermission: () async => request,
    getPosition: getPosition ?? () async => _pos(13.0827, 80.2707),
  );
}

Matcher _failsWith(LocationFailure failure) => throwsA(
      isA<LocationException>().having((e) => e.failure, 'failure', failure),
    );

void main() {
  test('returns the position when permission is already granted', () async {
    final pos = await _service().currentPosition();
    expect(pos.latitude, 13.0827);
    expect(pos.longitude, 80.2707);
  });

  test('prompts once when denied, then proceeds if granted', () async {
    var prompts = 0;
    final service = GeolocatorLocationService(
      isServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () async {
        prompts++;
        return LocationPermission.whileInUse;
      },
      getPosition: () async => _pos(1, 2),
    );
    final pos = await service.currentPosition();
    expect(prompts, 1);
    expect(pos.latitude, 1);
    expect(pos.longitude, 2);
  });

  test('GPS switched off fails as servicesDisabled', () {
    expect(
      () => _service(enabled: false).currentPosition(),
      _failsWith(LocationFailure.servicesDisabled),
    );
  });

  test('denying the prompt fails as permissionDenied', () {
    expect(
      () => _service(
        check: LocationPermission.denied,
        request: LocationPermission.denied,
      ).currentPosition(),
      _failsWith(LocationFailure.permissionDenied),
    );
  });

  test('a permanently blocked permission fails as permissionDeniedForever', () {
    expect(
      () => _service(check: LocationPermission.deniedForever).currentPosition(),
      _failsWith(LocationFailure.permissionDeniedForever),
    );
  });

  test('a slow fix fails as timeout', () {
    expect(
      () => _service(getPosition: () => throw TimeoutException('no fix'))
          .currentPosition(),
      _failsWith(LocationFailure.timeout),
    );
  });
}
