/// Why a device position could not be resolved. Each maps to a distinct,
/// user-actionable message (see `error_presentation.dart`).
enum LocationFailure {
  /// Location services (GPS) are switched off on the device.
  servicesDisabled,

  /// The user declined the location permission prompt.
  permissionDenied,

  /// Permission is permanently blocked; only device settings can restore it.
  permissionDeniedForever,

  /// No fix arrived in time (indoors, poor signal).
  timeout,
}

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;

  @override
  String toString() => 'LocationException(${failure.name})';
}

/// A resolved device position. Deliberately minimal — the app only ever needs
/// coordinates, never speed/heading/altitude.
class DevicePosition {
  const DevicePosition({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

/// Seam for reading the device's physical location, mirroring the
/// AttendanceService/AuthService pattern: screens depend on this interface,
/// so the platform plugin (or a fake in tests) can swap in freely.
abstract class LocationService {
  /// The device's current position. Throws [LocationException] when the
  /// position cannot be resolved for a user-actionable reason.
  Future<DevicePosition> currentPosition();
}
