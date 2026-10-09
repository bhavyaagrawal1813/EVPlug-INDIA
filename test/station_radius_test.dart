import 'package:evplug_new/utils/station_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jaipur city centre, used as the user origin throughout.
const double originLat = 26.9124;
const double originLng = 75.7873;

/// Builds a station roughly [distanceKm] north of the origin by walking
/// latitude, which on the Earth's surface is close to linear.
Map<String, dynamic> stationAtDistance(double distanceKm, {String id = 'x'}) {
  // 1 degree of latitude is about 111.2 km.
  return {
    'id': id,
    'name': 'Station $id',
    'geometry': {
      'location': {
        'lat': originLat + (distanceKm / 111.2),
        'lng': originLng,
      },
    },
  };
}

void main() {
  group('shared 50 km boundary', () {
    test('radius is 50 km', () {
      expect(kStationRadiusKm, 50.0);
    });

    test('boundary is inclusive at exactly 50 km', () {
      expect(isWithinStationRadius(49.999), isTrue);
      expect(isWithinStationRadius(50.0), isTrue);
      expect(isWithinStationRadius(50.001), isFalse);
      expect(isWithinStationRadius(80.0), isFalse);
    });
  });

  group('community stations use the same filter as google stations', () {
    test('community station beyond 50 km is excluded', () {
      final result = filterStationsWithinRadius(
        stations: [stationAtDistance(60, id: 'far')],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, isEmpty);
    });

    test('community station within 50 km is included', () {
      final result = filterStationsWithinRadius(
        stations: [stationAtDistance(12, id: 'near')],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, hasLength(1));
      expect(result.first['distanceKm'], closeTo(12, 0.5));
    });

    test('identical treatment regardless of source', () {
      final google = stationAtDistance(45, id: 'g');
      final community = stationAtDistance(45, id: 'c');
      google['source'] = 'google';
      community['source'] = 'community';

      final result = filterStationsWithinRadius(
        stations: [google, community],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, hasLength(2));
    });
  });

  group('distance is recalculated from the current origin', () {
    // Stations sit 5, 30 and 70 km north of the origin.
    final allStations = [
      stationAtDistance(5, id: 'close'),
      stationAtDistance(30, id: 'mid'),
      stationAtDistance(70, id: 'far'),
    ];

    double originShiftedNorth(double km) => originLat + (km / 111.2);

    test('only stations within 50 km show at the origin', () {
      final result = filterStationsWithinRadius(
        stations: allStations,
        originLat: originLat,
        originLng: originLng,
      );

      // close (5 km) and mid (30 km) are in range; far (70 km) is not.
      expect(result.map((s) => s['id']).toList(), ['close', 'mid']);
    });

    test('moving away changes which stations are visible', () {
      // 10 km north: close is 5 km away, mid is 20 km away, and far
      // (70 km) is now 60 km away so it drops out of range entirely.
      final result = filterStationsWithinRadius(
        stations: allStations,
        originLat: originShiftedNorth(10),
        originLng: originLng,
      );

      expect(result.map((s) => s['id']).toList(), ['close', 'mid']);
    });

    test('moving closer brings a distant station back into view', () {
      // 25 km north everything is still in range, but nearest-first
      // ordering flips because mid is now the closest station.
      final movedNorth = filterStationsWithinRadius(
        stations: allStations,
        originLat: originShiftedNorth(25),
        originLng: originLng,
      );

      expect(movedNorth.map((s) => s['id']).toList(), [
        'mid',
        'close',
        'far',
      ]);
      expect(movedNorth.first['distanceKm'], closeTo(5, 0.5));
    });

    test('moving closer restores stations that were previously hidden', () {
      // 140 km north puts every station beyond 50 km.
      final farResult = filterStationsWithinRadius(
        stations: allStations,
        originLat: originShiftedNorth(140),
        originLng: originLng,
      );

      expect(farResult, isEmpty);

      // Returning to the origin must bring them back again, proving the
      // filter never destroys the underlying station list.
      final nearResult = filterStationsWithinRadius(
        stations: allStations,
        originLat: originLat,
        originLng: originLng,
      );

      expect(nearResult.map((s) => s['id']).toList(), ['close', 'mid']);
    });

    test('results are sorted nearest first', () {
      final shuffled = [
        stationAtDistance(40, id: 'third'),
        stationAtDistance(2, id: 'first'),
        stationAtDistance(20, id: 'second'),
      ];

      final result = filterStationsWithinRadius(
        stations: shuffled,
        originLat: originLat,
        originLng: originLng,
      );

      expect(
        result.map((s) => s['id']).toList(),
        ['first', 'second', 'third'],
      );
    });
  });

  group('unusable coordinates never reach the user', () {
    test('missing geometry is dropped', () {
      final result = filterStationsWithinRadius(
        stations: [
          {'id': 'no-geo', 'name': 'Broken'},
          stationAtDistance(5, id: 'good'),
        ],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, hasLength(1));
      expect(result.first['id'], 'good');
    });

    test('out of range latitude is dropped', () {
      final result = filterStationsWithinRadius(
        stations: [
          {
            'id': 'bad-lat',
            'geometry': {
              'location': {'lat': 120.0, 'lng': 75.0},
            },
          },
        ],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, isEmpty);
    });

    test('non numeric coordinates are dropped', () {
      final result = filterStationsWithinRadius(
        stations: [
          {
            'id': 'string-coords',
            'geometry': {
              'location': {'lat': '26.9', 'lng': '75.7'},
            },
          },
        ],
        originLat: originLat,
        originLng: originLng,
      );

      expect(result, isEmpty);
    });
  });
}
