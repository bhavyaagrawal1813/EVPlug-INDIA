import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Why a location request failed, so the UI can react appropriately
/// instead of showing a generic error.
enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  final String message;

  const LocationFailure(this.reason, this.message);

  bool get canOpenSettings =>
      reason == LocationFailureReason.permissionDeniedForever ||
      reason == LocationFailureReason.serviceDisabled;

  @override
  String toString() => message;
}

class LocationService {
  static const Duration _fixTimeout = Duration(seconds: 20);

  /// Returns the user's real GPS position.
  ///
  /// Requests permission only when it has not been granted yet, uses a
  /// bounded timeout so a weak GPS fix cannot hang the screen, and throws
  /// a [LocationFailure] instead of a generic exception so callers can
  /// show an accurate message.
  static Future<Position> getCurrentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationFailureReason.serviceDisabled,
        'Location services are turned off. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
        'Location permission is permanently denied. '
        'Enable it from Settings to use nearby stations.',
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationFailureReason.permissionDenied,
        'Location permission denied.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
    } on TimeoutException {
      throw const LocationFailure(
        LocationFailureReason.timeout,
        'Could not get a GPS fix. Please try again in an open area.',
      );
    } catch (e) {
      throw LocationFailure(
        LocationFailureReason.unknown,
        'Could not determine your location.',
      );
    }
  }
}
