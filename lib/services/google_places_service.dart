import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class GooglePlacesService {
  // Replace with your Android Maps API Key
  static const String apiKey = Config.googleApiKey;

  static Future<List<Map<String, dynamic>>> fetchNearbyEVStations({
    required double latitude,
    required double longitude,
    double radius = 10000,
  }) async {
    final url = Uri.parse(
      'https://places.googleapis.com/v1/places:searchNearby',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.displayName,'
            'places.formattedAddress,'
            'places.location,'
            'places.rating,'
            'places.userRatingCount,'
            'places.currentOpeningHours,'
            'places.id,'
            'places.primaryType',
      },
      body: jsonEncode({
        "includedTypes": ["electric_vehicle_charging_station"],
        "maxResultCount": 20,
        "locationRestriction": {
          "circle": {
            "center": {
              "latitude": latitude,
              "longitude": longitude,
            },
            "radius": radius,
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["places"] != null) {
        return List<Map<String, dynamic>>.from(data["places"]);
      }

      return [];
    } else {
      throw Exception(response.body);
    }
  }
}