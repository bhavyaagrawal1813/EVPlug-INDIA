import 'package:evplug_new/widgets/station_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _communityStation() => {
      'id': 'community_1',
      'name':
          'Tata Power EZ Charge, Malviya Nagar Extension, Jaipur Rajasthan',
      'vicinity': 'Malviya Nagar Extension, Jaipur, Rajasthan 302017',
      'powerOutput': '22',
      'price': '12.50',
      'averageRating': 4.0,
      'distanceKm': 1.24,
      'geometry': {
        'location': {'lat': 26.9124, 'lng': 75.7873},
      },
    };

Map<String, dynamic> _googleStation() => {
      'place_id': 'google_1',
      'name': 'ChargePoint EV Charging Station, Vaishali Nagar',
      'vicinity': 'Vaishali Nagar, Jaipur, Rajasthan 302021',
      'rating': 4.4,
      'user_ratings_total': 218,
      'distanceKm': 3.9,
      'geometry': {
        'location': {'lat': 26.9124, 'lng': 75.7873},
      },
    };

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: false),
    home: Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  // Small phone sizes are where the previous fixed-height grid overflowed.
  for (final size in <Size>[
    const Size(360, 640),
    const Size(320, 640),
    const Size(411, 891),
  ]) {
    testWidgets('community card does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          StationCard(
            station: _communityStation(),
            isCommunity: true,
            onNavigate: (_, __) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('google card does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          StationCard(
            station: _googleStation(),
            isCommunity: false,
            onNavigate: (_, __) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('two sections separated by a divider do not overlap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            const StationSectionHeader(
              icon: Icons.bolt,
              color: StationSourceStyle.official,
              title: 'Google Listed Chargers',
              subtitle: 'Official source.',
              count: 1,
            ),
            StationList(
              stations: [_googleStation()],
              isCommunity: false,
              onNavigate: (_, __) {},
            ),
            const SizedBox(height: 20),
            const StationSectionHeader(
              icon: Icons.people,
              color: StationSourceStyle.community,
              title: 'Community Stations',
              subtitle: 'Community reported.',
              count: 1,
            ),
            StationList(
              stations: [_communityStation()],
              isCommunity: true,
              onNavigate: (_, __) {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('distance formatting avoids misleading 0.0 km', () {
    expect(formatStationDistance(0.42), '420 m away');
    expect(formatStationDistance(3.94), '3.9 km away');
    expect(formatStationDistance(null), 'Distance unavailable');
  });

  testWidgets('section header is tappable and shows an arrow affordance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        StationSectionHeader(
          icon: Icons.people,
          color: StationSourceStyle.community,
          title: 'Community Stations',
          subtitle: 'Community reported.',
          count: 4,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    await tester.tap(find.text('Community Stations'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tappable header without a callback has no arrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        const StationSectionHeader(
          icon: Icons.bolt,
          color: StationSourceStyle.official,
          title: 'Google Listed Chargers',
          subtitle: 'Official source.',
          count: 0,
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });
}
