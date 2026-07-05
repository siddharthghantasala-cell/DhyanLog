import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// [LocationService] backed by the platform GPS via `geolocator`. Runs the
/// permission flow (prompting once if the permission is merely denied) and
/// maps every failure to a typed [LocationException].
///
/// The platform calls are injectable so the permission/decision logic is unit
/// testable without a device.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    Future<bool> Function()? isServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function()? getPosition,
  })  : _isServiceEnabled =
            isServiceEnabled ?? Geolocator.isLocationServiceEnabled,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _getPosition = getPosition ?? _platformPosition;

  final Future<bool> Function() _isServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function() _getPosition;

  static Future<Position> _platformPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Attendance is a one-shot read at button press; better to fail fast
        // (the user can retry or fall back to the session code) than hang.
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  @override
  Future<DevicePosition> currentPosition() async {
    if (!await _isServiceEnabled()) {
      throw const LocationException(LocationFailure.servicesDisabled);
    }
    var permission = await _checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.permissionDenied);
    }
    try {
      final position = await _getPosition();
      return DevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    }
  }
}
