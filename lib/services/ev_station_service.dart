import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart';

class EVStationService {
  static const String _apiKey = Config.googleApiKey;

  // ============================================================
  // GOOGLE PLACE DETAILS (NEW)
  // ============================================================

  static Future<Map<String, dynamic>> fetchPlaceDetails(
    String placeId,
  ) async {
    final url = Uri.parse(
      'https://places.googleapis.com/v1/places/$placeId',
    );

    final response = await http.get(
      url,
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'id,'
            'displayName,'
            'formattedAddress,'
            'location,'
            'rating,'
            'userRatingCount,'
            'businessStatus,'
            'currentOpeningHours,'
            'googleMapsUri',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Place details error: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  // ============================================================
  // GOOGLE STATIONS NEAR ONE LOCATION
  // ============================================================

  static Future<List<Map<String, dynamic>>> fetchEVStations({
    required double lat,
    required double lng,
    int radius = 15000,
  }) async {
    if (!_isValidCoordinate(lat, lng)) {
      debugPrint(
        'EVStationService: refused search, invalid origin '
        '$lat,$lng',
      );
      return [];
    }

    // Plain radius ranking is used deliberately. rankby=distance would
    // return only the ~60 nearest places and silently drop stations in
    // the outer part of the 50 km range, which is exactly what the home
    // screen is meant to show.
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=$radius'
      '&type=charging_station'
      '&keyword=EV charging station'
      '&key=$_apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Could not load Google EV stations');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK' &&
        data['status'] != 'ZERO_RESULTS') {
      throw Exception(
        data['error_message'] ?? data['status'],
      );
    }

    final rawResults = List<Map<String, dynamic>>.from(
      data['results'] ?? [],
    );

    // Keep only results with a usable, in-range coordinate so the map and
    // distance calculations can never be fed a broken marker position.
    final validResults = rawResults.where((station) {
      final location = station['geometry']?['location'];

      final resultLat = location?['lat'];
      final resultLng = location?['lng'];

      if (resultLat is! num || resultLng is! num) return false;

      return _isValidCoordinate(
        resultLat.toDouble(),
        resultLng.toDouble(),
      );
    }).toList();

    validResults.sort(
      (a, b) => distanceKm(
        lat,
        lng,
        a['geometry']['location']['lat'].toDouble(),
        a['geometry']['location']['lng'].toDouble(),
      ).compareTo(
        distanceKm(
          lat,
          lng,
          b['geometry']['location']['lat'].toDouble(),
          b['geometry']['location']['lng'].toDouble(),
        ),
      ),
    );

    // Defence in depth: the radius above is Google's own bound, and this
    // keeps that guarantee even if the search settings change later.
    final radiusKm = radius / 1000;

    return validResults.where((station) {
      return distanceKm(
            lat,
            lng,
            station['geometry']['location']['lat'].toDouble(),
            station['geometry']['location']['lng'].toDouble(),
          ) <=
          radiusKm;
    }).toList();
  }

  // ============================================================
  // COORDINATE VALIDATION
  // ============================================================

  static bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.isInfinite || lng.isInfinite) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;

    // (0, 0) is a null island sentinel, not a real charger location.
    if (lat == 0 && lng == 0) return false;

    return true;
  }

  // ============================================================
  // GOOGLE STATIONS ALONG ENTIRE ROUTE
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      fetchStationsAlongRoute({
    required String encodedPolyline,
    int searchRadius = 5000,
  }) async {
    if (encodedPolyline.isEmpty) {
      return [];
    }

    final points = _decodePolyline(encodedPolyline);

    if (points.isEmpty) {
      return [];
    }

    final searchPoints = _selectRoutePoints(points);

    final Map<String, Map<String, dynamic>> uniqueStations = {};

    for (final point in searchPoints) {
      try {
        final stations = await fetchEVStations(
          lat: point['lat']!,
          lng: point['lng']!,
          radius: searchRadius,
        );

        for (final station in stations) {
          final placeId =
              station['place_id']?.toString();

          if (placeId == null || placeId.isEmpty) {
            continue;
          }

          final geometry = station['geometry'];
          final location = geometry?['location'];

          final stationLat =
              double.tryParse(
            location?['lat']?.toString() ?? '',
          );

          final stationLng =
              double.tryParse(
            location?['lng']?.toString() ?? '',
          );

          if (stationLat == null || stationLng == null) {
            continue;
          }

          // Check distance from the route search point.
          final distanceFromRoutePoint = distanceKm(
            point['lat']!,
            point['lng']!,
            stationLat,
            stationLng,
          );

          // Only keep stations reasonably close
          // to the actual route.
          if (distanceFromRoutePoint > 5.0) {
            continue;
          }

          uniqueStations[placeId] = {
            ...station,
            'source': 'Google',
            'latitude': stationLat,
            'longitude': stationLng,
            'distanceFromRouteKm':
                distanceFromRoutePoint,
          };
        }
      } catch (e) {
        debugPrint(
          'Error searching route point '
          '${point['lat']}, ${point['lng']}: $e',
        );
      }
    }

    return uniqueStations.values.toList();
  }

  // ============================================================
  // FIRESTORE COMMUNITY STATIONS
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      fetchCommunityStationsForAI() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('charging_stations')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      final latitude = double.tryParse(
        data['latitude']?.toString() ?? '',
      );

      final longitude = double.tryParse(
        data['longitude']?.toString() ?? '',
      );

      return {
        ...data,
        'id': doc.id,
        'stationName':
            data['stationName'] ?? 'Unknown',
        'location':
            data['location'] ?? 'Unknown',
        'latitude': latitude,
        'longitude': longitude,
        'source': 'EVPlug Community',
      };
    }).toList();
  }

  // ============================================================
  // ALL STATIONS NEAR CURRENT LOCATION
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      fetchAllStationsForAI({
    required double lat,
    required double lng,
    int radius = 5000,
  }) async {
    final googleStations = await fetchEVStations(
      lat: lat,
      lng: lng,
      radius: radius,
    );

    final communityStations =
        await fetchCommunityStationsForAI();

    final formattedGoogle =
        googleStationsForAI(googleStations);

    return [
      ...formattedGoogle,
      ...communityStations,
    ];
  }

  // ============================================================
  // FORMAT GOOGLE STATIONS
  // ============================================================

  static List<Map<String, dynamic>>
      googleStationsForAI(
    List<Map<String, dynamic>> stations,
  ) {
    return stations.map((station) {
      final geometry = station['geometry'];
      final location = geometry?['location'];

      return {
        'stationName':
            station['name'] ?? 'Unknown',

        'location':
            station['vicinity'] ??
                station['formatted_address'] ??
                'Unknown',

        'latitude':
            location?['lat'],

        'longitude':
            location?['lng'],

        'rating':
            station['rating'],

        'reviewCount':
            station['user_ratings_total'],

        'source':
            'Google',

        'placeId':
            station['place_id'],

        'businessStatus':
            station['business_status'],

        'openingHours':
            station['opening_hours'],
      };
    }).toList();
  }

  // ============================================================
  // DISTANCE BETWEEN TWO COORDINATES
  // ============================================================

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;

    final dLat =
        _degreesToRadians(lat2 - lat1);

    final dLon =
        _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c =
        2 * atan2(
          sqrt(a),
          sqrt(1 - a),
        );

    return earthRadius * c;
  }

  static double _degreesToRadians(
    double degrees,
  ) {
    return degrees * pi / 180;
  }

  // ============================================================
  // ADD DISTANCE FROM START
  // ============================================================

  static List<Map<String, dynamic>>
      addDistanceFromLocation({
    required List<Map<String, dynamic>> stations,
    required double latitude,
    required double longitude,
  }) {
    return stations.map((station) {
      final lat = double.tryParse(
        station['latitude']?.toString() ?? '',
      );

      final lng = double.tryParse(
        station['longitude']?.toString() ?? '',
      );

      if (lat == null || lng == null) {
        return {
          ...station,
          'distanceKm': null,
        };
      }

      return {
        ...station,
        'distanceKm': distanceKm(
          latitude,
          longitude,
          lat,
          lng,
        ),
      };
    }).toList();
  }

  // ============================================================
  // SORT BY DISTANCE
  // ============================================================

  static List<Map<String, dynamic>>
      sortByDistance(
    List<Map<String, dynamic>> stations,
  ) {
    final sorted = [...stations];

    sorted.sort((a, b) {
      final aDistance =
          a['distanceKm'] as double?;

      final bDistance =
          b['distanceKm'] as double?;

      if (aDistance == null) return 1;
      if (bDistance == null) return -1;

      return aDistance.compareTo(bDistance);
    });

    return sorted;
  }

  // ============================================================
  // JSON FOR GEMINI
  // ============================================================

  static String stationsToAIJson(
    List<Map<String, dynamic>> stations,
  ) {
    return jsonEncode(
      stations.map((station) {
        return {
          'name':
              station['stationName'] ??
                  station['name'] ??
                  'Unknown',

          'source':
              station['source'] ??
                  'Unknown',

          'location':
              station['location'] ??
                  station['vicinity'] ??
                  'Unknown',

          'latitude':
              station['latitude'],

          'longitude':
              station['longitude'],

          'distanceKm':
              station['distanceKm'],

          'distanceFromRouteKm':
              station['distanceFromRouteKm'],

          'rating':
              station['rating'],

          'reviewCount':
              station['reviewCount'] ??
                  station['user_ratings_total'],

          'price':
              station['price'],

          'power':
              station['powerOutput'],

          'placeId':
              station['placeId'] ??
                  station['place_id'],
        };
      }).toList(),
    );
  }

  // ============================================================
  // POLYLINE DECODER
  // ============================================================

  static List<Map<String, double>>
      _decodePolyline(String encoded) {
    final List<Map<String, double>> points = [];

    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final dLat =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      lat += dLat;

      shift = 0;
      result = 0;

      do {
        byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final dLng =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      lng += dLng;

      points.add({
        'lat': lat / 1e5,
        'lng': lng / 1e5,
      });
    }

    return points;
  }

  // ============================================================
  // SELECT POINTS THROUGHOUT ENTIRE ROUTE
  // ============================================================

  static List<Map<String, double>>
      _selectRoutePoints(
    List<Map<String, double>> points,
  ) {
    if (points.isEmpty) {
      return [];
    }

    final List<Map<String, double>> selected = [];

    // Instead of using every 20th polyline point,
    // divide the route into approximately equal sections.

    const int maxSearchPoints = 20;

    final step =
        max(1, (points.length / maxSearchPoints).ceil());

    for (
      int i = 0;
      i < points.length;
      i += step
    ) {
      selected.add(points[i]);
    }

    // Always include the final point.
    if (selected.isEmpty ||
        selected.last['lat'] != points.last['lat'] ||
        selected.last['lng'] != points.last['lng']) {
      selected.add(points.last);
    }

    return selected;
  }
}