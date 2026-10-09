import 'package:geolocator/geolocator.dart';

/// The single visibility boundary shared by every station source.
///
/// Official (Google) and community stations use this same value, so the
/// only thing that distinguishes the two lists is where the station data
/// came from, not how far away it is allowed to be.
const double kStationRadiusKm = 50.0;

/// Whether a station is close enough to the user to be shown.
bool isWithinStationRadius(double distanceKm) {
  return distanceKm <= kStationRadiusKm;
}

/// Reads a station coordinate, returning null when it is missing or
/// outside valid latitude/longitude bounds.
///
/// A station with unusable coordinates is never shown, because it could
/// not be given a trustworthy distance or marker position.
({double lat, double lng})? stationCoordinate(
  Map<String, dynamic> station,
) {
  final lat = station['geometry']?['location']?['lat'];
  final lng = station['geometry']?['location']?['lng'];

  if (lat is! num || lng is! num) return null;

  final latValue = lat.toDouble();
  final lngValue = lng.toDouble();

  if (latValue.isNaN || lngValue.isNaN) return null;
  if (latValue < -90 || latValue > 90) return null;
  if (lngValue < -180 || lngValue > 180) return null;

  return (lat: latValue, lng: lngValue);
}

/// Filters [stations] to those within [kStationRadiusKm] of the given
/// origin, attaching a `distanceKm` value to each and sorting nearest
/// first.
///
/// Returns an empty list when there is no origin, so a station is never
/// displayed against an unknown position.
List<Map<String, dynamic>> filterStationsWithinRadius({
  required List<Map<String, dynamic>> stations,
  required double originLat,
  required double originLng,
}) {
  final prepared = <Map<String, dynamic>>[];

  for (final station in stations) {
    final coordinate = stationCoordinate(station);

    if (coordinate == null) continue;

    final distanceKm = Geolocator.distanceBetween(
      originLat,
      originLng,
      coordinate.lat,
      coordinate.lng,
    ) / 1000;

    if (!isWithinStationRadius(distanceKm)) continue;

    prepared.add({...station, 'distanceKm': distanceKm});
  }

  prepared.sort(
    (a, b) => (a['distanceKm'] as double).compareTo(
      (b['distanceKm'] as double),
    ),
  );

  return prepared;
}
