import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class EVRouteService {
  static const String _apiKey = Config.googleApiKey;

  // ============================================================
  // GET ROUTE
  // ============================================================

  static Future<Map<String, dynamic>> getRoute({
    required double startLat,
    required double startLng,
    required String destination,
  }) async {
    final destinationCoordinates =
        await _geocodeDestination(destination);

    if (destinationCoordinates == null) {
      throw Exception('Destination not found');
    }

    final url = Uri.parse(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );

    final body = {
      "origin": {
        "location": {
          "latLng": {
            "latitude": startLat,
            "longitude": startLng,
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destinationCoordinates['lat'],
            "longitude": destinationCoordinates['lng'],
          }
        }
      },
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": false,
      "languageCode": "en-IN",
      "units": "METRIC",
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'routes.distanceMeters,'
            'routes.duration,'
            'routes.polyline.encodedPolyline',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Routes API error: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['routes'] == null ||
        data['routes'].isEmpty) {
      throw Exception('No route found');
    }

    final route = data['routes'][0];

    return {
      'distanceKm':
          (route['distanceMeters'] ?? 0) / 1000,

      'duration':
          route['duration'] ?? '',

      'polyline':
          route['polyline']?['encodedPolyline'] ?? '',

      'destinationLatitude':
          destinationCoordinates['lat'],

      'destinationLongitude':
          destinationCoordinates['lng'],
    };
  }

static Future<double?> getDrivingDistanceKm({
  required double startLat,
  required double startLng,
  required double destinationLat,
  required double destinationLng,
}) async {
  final url = Uri.parse(
    'https://routes.googleapis.com/directions/v2:computeRoutes',
  );

  final body = {
    "origin": {
      "location": {
        "latLng": {
          "latitude": startLat,
          "longitude": startLng,
        }
      }
    },
    "destination": {
      "location": {
        "latLng": {
          "latitude": destinationLat,
          "longitude": destinationLng,
        }
      }
    },
    "travelMode": "DRIVE",
    "routingPreference": "TRAFFIC_AWARE",
    "computeAlternativeRoutes": false,
    "languageCode": "en-IN",
    "units": "METRIC",
  };

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'routes.distanceMeters',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['routes'] == null ||
        data['routes'].isEmpty) {
      return null;
    }

    final distanceMeters =
        data['routes'][0]['distanceMeters'];

    if (distanceMeters == null) {
      return null;
    }

  final distanceKm =
    (distanceMeters as num) / 1000;

debugPrint(
  '🚗 GOOGLE ROUTE DISTANCE: '
  '${distanceKm.toStringAsFixed(2)} km',
);

return distanceKm;
  } catch (e) {
    return null;
  }
}


  // ============================================================
  // GOOGLE PLACES ALONG ROUTE
  // ============================================================

  static Future<List<Map<String, dynamic>>>
      findEVStationsAlongRoute({
    required String encodedPolyline,
  }) async {
    if (encodedPolyline.isEmpty) {
      return [];
    }

    final url = Uri.parse(
      'https://places.googleapis.com/v1/places:searchText',
    );

    final body = {
      "textQuery": "EV charging station",
      "pageSize": 20,
      "searchAlongRouteParameters": {
        "polyline": {
          "encodedPolyline": encodedPolyline,
        }
      },
      "languageCode": "en-IN",
    };

    final response = await http.post(
      
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'places.id,'
            'places.displayName,'
            'places.formattedAddress,'
            'places.location,'
            'places.rating,'
            'places.userRatingCount,'
            'places.businessStatus,'
            'places.googleMapsUri',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Places route search error: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final places =
        List<Map<String, dynamic>>.from(
      data['places'] ?? [],
    );

    return places.map((place) {
      final location =
          place['location'] ?? {};

      final displayName =
          place['displayName'] ?? {};

      return {
        'stationName':
            displayName['text'] ?? 'Unknown',

        'location':
            place['formattedAddress'] ?? 'Unknown',

        'latitude':
            location['latitude'],

        'longitude':
            location['longitude'],

        'rating':
            place['rating'],

        'reviewCount':
            place['userRatingCount'],

        'placeId':
            place['id'],

        'businessStatus':
            place['businessStatus'],

        'googleMapsUri':
            place['googleMapsUri'],

        'source':
            'Google',

        'liveAvailability':
            false,

        'availabilityStatus':
            'Live availability not connected',
      };
    }).toList();
  }

  // ============================================================
  // GEOCODE DESTINATION
  // ============================================================

  static Future<Map<String, double>?>
      _geocodeDestination(
    String destination,
  ) async {
    final encoded =
        Uri.encodeComponent(destination);

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=$encoded'
      '&key=$_apiKey',
    );

    final response =
        await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data =
        jsonDecode(response.body);

    if (data['status'] != 'OK' ||
        data['results'].isEmpty) {
      return null;
    }

    final location =
        data['results'][0]['geometry']['location'];

    return {
      'lat':
          (location['lat'] as num).toDouble(),

      'lng':
          (location['lng'] as num).toDouble(),
    };
  }

  static Future<String> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&key=${Config.googleApiKey}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return 'Location: ${(lat).toStringAsFixed(4)}, ${(lng).toStringAsFixed(4)}';
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
        return 'Location: ${(lat).toStringAsFixed(4)}, ${(lng).toStringAsFixed(4)}';
      }

      final results = data['results'] as List;

      // Prefer a street-address-level result if available.
      Map<String, dynamic>? best;
      for (final r in results) {
        final types = (r['types'] as List?) ?? const [];
        if (types.contains('street_address') ||
            types.contains('premise')) {
          best = r;
          break;
        }
      }
      best ??= results.first;

      final address = best?['formatted_address']?.toString();
      if (address == null || address.isEmpty) {
        return 'Location: ${(lat).toStringAsFixed(4)}, ${(lng).toStringAsFixed(4)}';
      }
      return address;
    } catch (e) {
      return 'Location: ${(lat).toStringAsFixed(4)}, ${(lng).toStringAsFixed(4)}';
    }
  }

}