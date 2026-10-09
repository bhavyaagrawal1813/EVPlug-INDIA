import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/gemini_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/review_service.dart';
import 'dart:convert';
import '../services/ev_station_service.dart';
import '../services/ev_route_service.dart';
class EvAiScreen extends StatefulWidget {
  final Map<String, dynamic>? station;

  const EvAiScreen({
    super.key,
    this.station,
  });

  @override
  State<EvAiScreen> createState() => _EvAiScreenState();
}

class _EvAiScreenState extends State<EvAiScreen> {
final TextEditingController _messageController = TextEditingController();
final TextEditingController _batteryController = TextEditingController();
final TextEditingController _manualLocationController = TextEditingController();
final TextEditingController _destinationController = TextEditingController();
final ScrollController _scrollController = ScrollController();
final FocusNode _messageFocusNode = FocusNode();

String _aiReply = '';
bool _isLoading = false;
bool _isProfileLoading = true;
Position? _currentPosition;
bool _isGettingLocation = false;
final ReviewService _reviewService = ReviewService();

Map<String, dynamic>? _stationAiData;

String _carName = '';
String _vehicleNumber = '';
double? _estimatedRangeKm;
double? _batteryPercentage;
StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    _profileSubscription;
final Completer<void> _firstProfileReceived = Completer<void>();
@override
void initState() {
  super.initState();

  _loadVehicleProfile();

  if (widget.station != null && GeminiService.isEnabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _stationAiData = await _reviewService.getStationAiData(
        isGoogle: widget.station!["source"] == "google",
        stationId: widget.station!["source"] == "google"
            ? widget.station!["place_id"]
            : widget.station!["id"],
      );

      // Wait for the first vehicle profile snapshot so the AI gets
      // an accurate vehicle context.
      await _firstProfileReceived.future;
      if (!mounted) return;
      await _sendMessage();
    });
  }
}

@override
void dispose() {
_profileSubscription?.cancel();
_messageController.dispose();
_batteryController.dispose();
_scrollController.dispose();
_messageFocusNode.dispose();
_manualLocationController.dispose();
_destinationController.dispose();
super.dispose();
}

void _loadVehicleProfile() {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    if (!mounted) return;

    setState(() {
      _isProfileLoading = false;
    });
    if (!_firstProfileReceived.isCompleted) {
      _firstProfileReceived.complete();
    }
    return;
  }

  _profileSubscription = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .listen(
    (document) {
      final data = document.data();

      if (!mounted) return;

      final rangeValue = data?['estimatedRangeKm'];
      final parsedRange = double.tryParse(rangeValue?.toString() ?? '');

      setState(() {
        _carName = data?['carName']?.toString().trim() ?? '';
        _vehicleNumber = data?['vehicleNumber']?.toString().trim() ?? '';
        _estimatedRangeKm = parsedRange;
        _isProfileLoading = false;
      });

      if (!_firstProfileReceived.isCompleted) {
        _firstProfileReceived.complete();
      }
    },
    onError: (_) {
      if (!mounted) return;

      setState(() {
        _isProfileLoading = false;
      });
      if (!_firstProfileReceived.isCompleted) {
        _firstProfileReceived.complete();
      }
    },
  );
}

void _updateBatteryPercentage(String value) {
final battery = double.tryParse(value);


setState(() {
  if (battery == null || battery < 0 || battery > 100) {
    _batteryPercentage = null;
  } else {
    _batteryPercentage = battery;
  }
});


}

double? get _remainingRangeKm {
if (_estimatedRangeKm == null || _batteryPercentage == null) {
return null;
}


return _estimatedRangeKm! * _batteryPercentage! / 100;


}

void _scrollToBottom() {
Future.delayed(const Duration(milliseconds: 300), () {
if (_scrollController.hasClients) {
_scrollController.animateTo(
_scrollController.position.maxScrollExtent,
duration: const Duration(milliseconds: 350),
curve: Curves.easeOut,
);
}
});
}
Future<void> _getCurrentLocation() async {
  setState(() {
    _isGettingLocation = true;
  });

  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        _aiReply = 'Please turn on your phone location service first.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _aiReply = 'Location permission is needed to find nearby charging stations.';
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    setState(() {
      _currentPosition = position;
      _aiReply =
          'Location updated. EV AI can now use your current location for charging suggestions.';
    });
  } catch (e) {
    setState(() {
      _aiReply = 'Could not get your location. Please try again.';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }
}



Future<void> _sendQuickAction(String action) async {
  String message = '';

 if (action == 'Fast Charger') {
  message = '''
NORMAL EV STATION SEARCH.

Find the nearest fast charging stations for me.

This is NOT station authenticity analysis.

Do NOT calculate:
- Trust Score
- Classification
- Confidence
- Evidence Summary

Battery percentage is NOT required for this search.

Do NOT ask me for battery percentage unless I specifically ask whether a station is reachable with my current battery.

Use BOTH:
1. Google-listed EV charging stations
2. EVPlug community-added stations

Merge both sources.

For each station show:
- Station name
- Source (Google / EVPlug Community)
- Distance from my current location
- Charging power if available
- Price if available
- Rating if available

Sort by nearest distance first.

Keep the answer short and practical.

Do not say that live charging-station data is unavailable if station data has been provided below.
''';
} else if (action == 'Cheapest') {
    message = '''
NORMAL EV STATION SEARCH.

Find the cheapest suitable charging stations near me.

This is NOT station authenticity analysis.
Do NOT show Trust Score, Classification, Confidence, or Evidence Summary.

Use BOTH Google-listed stations and EVPlug community stations.

Show:
- Station name
- Source
- Distance
- Price
- Charging power
- Rating if available

Sort by price, while also considering reasonable distance.
''';
  } else if (action == 'Best Station') {
    message = '''
NORMAL EV STATION SEARCH.

Find the best suitable EV charging stations near me.

This is NOT station authenticity analysis.
Do NOT show Trust Score, Classification, Confidence, or Evidence Summary.

Use BOTH Google-listed stations and EVPlug community stations.

Consider:
- Distance
- Charging speed
- Price
- Rating
- Reviews when available

Show the most useful stations first.
''';
  } else if (action == 'On Route') {
    message = '''
NORMAL EV ROUTE PLANNING.

Help me find charging stations on my route.

This is NOT station authenticity analysis.
Do NOT show Trust Score, Classification, Confidence, or Evidence Summary.

Use BOTH:
- Google-listed EV stations
- EVPlug community stations

Show stations in travel order from start to destination.

For each station show:
- Station name
- Source
- Area/city
- Distance from start
- Distance from previous station
- Charging power if available
- Price if available
- Rating if available

Do not invent station information.
''';
  }


  _messageController.text = message;
  await _sendMessage(quickAction: action);
}

Future<void> _sendMessage({String? quickAction}) async {
String message = _messageController.text.trim();

// The AI feature is deferred for production. Short-circuit before any
// Firestore or Places API call so no cost is incurred and the app
// never depends on AI.
if (!GeminiService.isEnabled) {
  _messageController.clear();
  if (!mounted) return;
  setState(() {
    _aiReply = GeminiService.disabledMessage;
  });
  _scrollToBottom();
  return;
}

final bool isStationAnalysis =
    widget.station != null && message.isEmpty;

// Automatically analyze station if opened from Station Details
if (isStationAnalysis) {
  message =
      "Analyze this specific charging station for authenticity. "
      "Calculate Trust Score, Classification, and Confidence.";
}
if (message.isEmpty) return;

final batteryText = _batteryController.text.trim();
final batteryValue = double.tryParse(batteryText);

if (batteryText.isNotEmpty &&
    (batteryValue == null || batteryValue < 0 || batteryValue > 100)) {
  setState(() {
    _aiReply = 'Please enter a battery percentage between 0 and 100.';
  });
  _scrollToBottom();
  return;
}

setState(() {
  _isLoading = true;
});

_messageController.clear();
_scrollToBottom();

final locationText = _currentPosition == null
    ? 'Not available'
    : 'Latitude: ${_currentPosition!.latitude}, Longitude: ${_currentPosition!.longitude}';

final remainingRangeText = _remainingRangeKm == null
    ? 'Not available'
    : '${_remainingRangeKm!.toStringAsFixed(1)} km';

final estimatedRangeText = _estimatedRangeKm == null
    ? 'Not available'
    : '${_estimatedRangeKm!.toStringAsFixed(1)} km';

final batteryPercentageText = _batteryPercentage == null
    ? 'Not available'
    : '${_batteryPercentage!.toStringAsFixed(0)}%';

String stationAge = "Unknown";
List<String> nearbyStationNames = [];
try {
  // ================================
  // GET EVPLUG COMMUNITY STATIONS
  // ================================

  final stationsSnapshot = await FirebaseFirestore.instance
      .collection("charging_stations")
      .get();

  nearbyStationNames = stationsSnapshot.docs
    .map((e) => e.data()["stationName"]?.toString() ?? "")
    .where((name) => name.isNotEmpty)
    .toList();

  final evPlugStations = stationsSnapshot.docs.map((doc) {
    final data = doc.data();

    return {
      ...data,
      "source": "EVPlug Community",
    };
  }).toList();

  // ================================
  // GET GOOGLE STATIONS
  // ================================

  List<Map<String, dynamic>> googleStations = [];

  if (_currentPosition != null) {
    googleStations = await EVStationService.fetchEVStations(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
    );

    googleStations = googleStations.map((station) {
      return {
        ...station,
        "source": "Google",
      };
    }).toList();
  }

  // ================================
  // MERGE BOTH SOURCES
  // ================================

  final allStations = [
    ...googleStations,
    ...evPlugStations,
  ];

  List<Map<String, dynamic>> stationDataForAI = allStations.map((station) {
    return {
      "name": station["name"] ?? station["stationName"] ?? "Unknown",
      "source": station["source"] ?? "Unknown",
      "address": station["formatted_address"] ??
          station["location"] ??
          "Unknown",
      "rating": station["rating"],
      "reviews": station["user_ratings_total"],
      "power": station["powerOutput"],
      "price": station["price"],
      "latitude": station["geometry"]?["location"]?["lat"] ??
          station["latitude"],
      "longitude": station["geometry"]?["location"]?["lng"] ??
          station["longitude"],
    };
  }).toList();

  String verificationNote = "";

  if (quickAction == 'Fast Charger' || quickAction == 'Cheapest') {
    stationDataForAI = _filterStationsForQuickAction(stationDataForAI, quickAction!);

    if (quickAction == 'Fast Charger') {
      verificationNote = "\n\nVERIFIED FAST CHARGERS:\n"
          "The app has already filtered stations by charging power and distance. "
          "Use ONLY these verified stations. Do not invent additional stations or data.";
    } else if (quickAction == 'Cheapest') {
      verificationNote = "\n\nVERIFIED CHEAPEST CHARGERS:\n"
          "The app has already filtered stations by price and distance. "
          "Use ONLY these verified stations. Do not invent additional stations or data.";
    }
  }

  final String stationDataText = quickAction != null
      ? jsonEncode(stationDataForAI)
      : "";

  if (widget.station?["createdAt"] != null) {
  final created = widget.station!["createdAt"] as Timestamp;
  final createdDate = created.toDate();

  final days = DateTime.now().difference(createdDate).inDays;

  if (days < 30) {
    stationAge = "$days days old";
  } else if (days < 365) {
    stationAge = "${(days / 30).floor()} months old";
  } else {
    stationAge = "${(days / 365).floor()} years old";
  }
  }
  final response = await GeminiService.generateResponse(
  '''



You are EV AI, an electric vehicle charging assistant for the EVPlug app.

You only support electric vehicle travel, charging stations, charging prices, EV routes, EV policies, and EV guidance within India.

Important India-only rules:
1. EVPlug supports India only.

2. If phone GPS is outside India, do not describe the foreign location in detail.
Do not mention USA, California, Mountain View, foreign coordinates, or foreign places in the reply.

3. If phone GPS is outside India but the user manually enters an Indian start location and Indian destination, use the manual Indian start location for the trip.

4. If phone GPS is outside India and no manual Indian start location is entered, say only:
"Your phone location is outside India. Please enter an Indian start location manually."

5. Never assume Jaipur, Ajmer, Delhi, Mumbai, or any other city. Use only the locations typed by the user.

6. Do not invent charging station names, addresses, distances, prices, connector types, or charging speeds.
LIVE DATA RULE:

Station listing data may be provided by Google and EVPlug Community.

However, LIVE CHARGER AVAILABILITY is NOT connected.

Therefore:

- You may use the station data provided in this prompt.
- You may recommend those stations as estimated options.
- Do NOT say a charger is currently free.
- Do NOT say a charger is currently occupied.
- Do NOT say a charger is currently working.
- Do NOT claim real-time availability.
- Do NOT invent stations that are not provided.
- Clearly tell the user:

"Live charging-station availability is not connected yet."
EXCEPTION:
If Station Details are provided in this prompt, ignore this rule completely and perform the Station Authenticity Analysis instead.

8. When live station data is available, show every available station on the route in ascending order from start to destination, using this format:

1. Station name
   Location
   Distance from start
   Distance from previous station
   Connector
   Charging speed
   Price
   Reachability status

9. Keep safety advice to one short sentence only:
"Check live availability, connector compatibility, and pricing before leaving."

10. Recommend or discuss charging stations only in India.

11. Use kilometres (km), Indian rupees (₹), and Indian road/travel context.

12. If the user asks about a location, charging station, route, or EV service outside India, clearly say that EVPlug currently supports India only.

13. Do not recommend foreign charging networks, foreign currencies, or stations outside India.

14. 14. Do not repeat safety warnings. Use only rule 9 as the final safety note.

15. For trip planning, keep the response concise and show a maximum of 8 important route stations unless the user asks for more.
Use the following vehicle context for every answer:

* Car name: ${_carName.isEmpty ? 'Not available' : _carName}
* Vehicle/RTO number: ${_vehicleNumber.isEmpty ? 'Not available' : _vehicleNumber}
* Estimated full range from Profile: $estimatedRangeText
* Current battery percentage: $batteryPercentageText
* Calculated remaining range: $remainingRangeText
- Phone GPS location: $locationText
- Manual start location entered by user: ${_manualLocationController.text.trim().isEmpty ? 'Not provided' : _manualLocationController.text.trim()}
Rules:

1. Use this vehicle context for EV charging recommendations.
2. Never invent vehicle range, battery percentage, or remaining range.
3. Battery percentage is required only when checking whether a station is reachable, finding nearby reachable chargers, or planning charging stops based on current range.
4. For a normal trip-planning request, ask for the destination first and do not require battery percentage immediately.
5. If battery percentage is missing for a reachability recommendation, politely ask the user to enter it.
6. Keep answers practical, short, and helpful for an EV driver.
7. Do not claim a charging station is reachable unless the available remaining range supports it.
8. Treat the calculated remaining range as an estimate, not an exact guarantee.
9. Keep a safety reserve of at least 15% battery or 20 km, whichever is greater.
10. Do not call a station safely reachable if reaching it would leave less than the safety reserve.
11. Keep safety guidance to one short sentence at the end only.
12. For every trip request inside India, give an ESTIMATED TRIP PLAN, not an exact trip plan.
13. When the user gives both current location and destination, list charging stations that are on or reasonably close to the route in ascending travel order from start to destination.
14. Use this format for trip answers:

ESTIMATED TRIP PLAN
Start: [starting location]
Destination: [destination]

1. First charging station
- Station name:
- Area/city:
- Approximate distance from start:
- Approximate distance from previous stop:
- Charger/connector:
- Charging speed:
- Estimated charging price:
- Reachability based on current battery: [only if battery is available]

2. Second charging station
- Station name:
- Area/city:
- Approximate distance from start:
- Approximate distance from previous stop:
- Charger/connector:
- Charging speed:
- Estimated charging price:
- Reachability based on current battery: [only if battery is available]

Continue the station list in the same ascending route order until the destination.

16. If real-time route, station, price, connector, or availability data is not available, clearly say it is an estimate and ask the driver to verify it in Google Maps or the charging operator app before starting.
17. Never make up a charging-station name, exact price, exact route distance, or live availability.

${quickAction != null && stationDataText.isNotEmpty ? 'AVAILABLE STATION DATA:\n$stationDataText\n$verificationNote\n' : ''}User message: $message
Response speed rules:
1. Keep every answer under 180 words.
2. Do not repeat the full EV safety warning in every answer.
3. For a trip plan, show only the most useful charging stops first.
4. Use short station cards, not long paragraphs.
5. If live verified station data is unavailable, say it once in one short line.
6. Never repeat the vehicle details unless the user asks.

STATION ANALYSIS MODE:

Only perform station authenticity analysis when the user is explicitly asking to analyze the specific station provided from Station Details.

For normal EV searches, Fast Charger, Cheapest, Best Station, On Route, and trip planning:
- Do NOT perform station authenticity analysis.
- Do NOT calculate Trust Score.
- Do NOT show Classification.
- Do NOT show Confidence.
- Do NOT show Evidence Summary.
- Use the provided Google and EVPlug station data to recommend stations.
Station Name:
${widget.station?["stationName"] ?? widget.station?["name"] ?? "Unknown"}

Address:
${widget.station?["location"] ?? widget.station?["vicinity"] ?? "Unknown"}

Distance:
${widget.station?["distanceKm"] ?? "Unknown"} km

Power Output:
${widget.station?["powerOutput"] ?? "Not Available"} kW

Charging Price:
₹${widget.station?["price"] ?? "Not Available"}/kWh

Station Source:
${widget.station?["source"] ?? "Unknown"}

Station Created:
${widget.station?["createdAt"] ?? "Unknown"}

Station AI Data:
${_stationAiData ?? {}}
Existing EVPlug Station Names:
$nearbyStationNames


Station Source:
${widget.station?["source"] ?? "unknown"}

If Station Source = "google", also use these Google fields if available:

Google Rating:
${widget.station?["rating"] ?? "Unknown"}

Google Review Count:
${widget.station?["user_ratings_total"] ?? "Unknown"}

Business Status:
${widget.station?["business_status"] ?? "Unknown"}

Google Place ID:
${widget.station?["place_id"] ?? "Unknown"}

Opening Status:
${widget.station?["opening_hours"] ?? "Unknown"}

Station Age:
$stationAge
Analysis Rules for Station Source:

1. First identify the station source.

2. If Station Source = "google":
- Treat it as a Google Maps station.
- Google listing is a positive trust indicator.
- Do NOT assume it is genuine only because it is on Google.
- Reviews, reports, pricing consistency and other available data can still reduce the Trust Score.
- Mention in the analysis that it is a Google-listed station.

3. If Station Source = "user" or "community":
- Treat it as a Community Added Station.
- Evaluate it more carefully because it was added by an EVPlug user.
- Place greater emphasis on:
  • review quality
  • review count
  • report count
  • realistic pricing
  • realistic station name
  • location quality
  • power output
- Mention in the analysis that it is a Community Added Station.

4. Never reduce the Trust Score simply because a station is community-added.

5. Never give a Google station a perfect Trust Score only because it is listed on Google.

6. Include the station source in the final report.

Example:

Station Source:
Google Listed

or

Station Source:
Community Added

For station analysis:
If Station Details are provided:

Ignore all EV trip-planning instructions.

Ignore battery calculations.

Ignore routing.

Ignore destination planning.

Focus ONLY on station authenticity analysis.
1. Calculate a Trust Score from 0–100.
2. Classify the station as:
   - Likely Genuine
   - Needs Verification
   - Potentially Suspicious

3. Consider ONLY the information available inside EVPlug.

Evaluate using:
- Types and seriousness of user reports (for example: fake location, station not found, permanently closed, wrong pricing).
- Station name quality (does the name look like a real charging station?)
- Address/location quality
- Power output (if available)
- Charging price (if available)
- Rating consistency
- Number of reviews
- Review quality
- Suspicious review patterns
- Number of reports
- Duplicate or suspicious station names
- Whether the available EVPlug information appears realistic and internally consistent.
- Station age (createdAt) should be considered when evaluating trust.

- A newly added station should NOT receive a lower Trust Score simply because it has few reviews or no reviews.

- If the station is new (for example less than 30 days old), lower the Confidence rather than the Trust Score when review history is limited.

- Older stations are expected to have more reviews and a more established reputation. If an old station has very few reviews, many reports, or inconsistent feedback, this should reduce the Trust Score.

- Always evaluate reviews and reports in relation to the station's age.

- Mention the station age in the Reasons section whenever it affects the final decision.

- Never assume a station is fake only because it was recently added.
Do NOT reduce the trust score because connector type, charging network/operator, amenities, opening hours, parking information, photos, or any other fields are missing if EVPlug does not collect those fields.

4. Never claim with certainty that a station is fake.

Estimate authenticity only from the information supplied by EVPlug.

If EVPlug does not collect a particular field, completely ignore that field during analysis.

Do not assume missing information means the station is fake.

5. Explain why you reached your conclusion.

6. End with a short recommendation for EV drivers.

7. If the station name resembles a well-known charging network (for example Tata Power EZ Charge, Statiq, ChargeZone, Jio-bp Pulse, Zeon, Bolt.Earth, Shell Recharge, Glida, Kazam, or other recognized Indian charging operators), treat that as a positive indicator only if the remaining information is also consistent.

8. If the station uses a generic name such as "EV Station", "Charging Point", or random words, do not automatically mark it as suspicious. Instead, rely on reviews, reports, pricing, and overall consistency.

9. A high number of genuine reviews with very few reports should increase confidence.

10. Multiple reports, unrealistic pricing, repetitive review text, or conflicting ratings should decrease confidence.

11. Explain every increase or decrease in the Trust Score with a specific reason based on the available data.

12. Compare the station name with existing EVPlug station names.

13. If another station has an identical or very similar name, first determine whether it belongs to the same charging network with a different branch or location.

14. Only reduce the Trust Score if the station appears to be a duplicate at the same or nearby location, intentionally misleading, or inconsistent with its address and other available information.

15. Legitimate charging networks may have many stations with the same brand name. Do not treat those as suspicious unless other evidence supports it.
Confidence should reflect the quality of available evidence.
16. Compare the station name with the provided "Existing EVPlug Station Names" list.

17. If the same station name appears multiple times:
- Compare the locations.
- Compare the charging prices.
- Compare the power output.
- Compare the reviews and reports.
- Decide whether they appear to be different branches of the same charging network or a suspicious duplicate.

18. If multiple stations have identical names and nearly identical locations, treat this as a possible duplicate listing and reduce the Confidence.

19. If multiple stations have the same operator name but different cities or different coordinates, treat them as legitimate branches unless other evidence suggests otherwise.

20. Never reduce the Trust Score solely because multiple stations share the same brand name.
Confidence represents how certain EV AI is about the Trust Score.

Confidence is based on:
• Number of reviews
• Review quality
• Number of reports
• Station age
• Rating consistency
• Information completeness
• Agreement between Google data and EVPlug data (if available)

Confidence Guide:

90–100%
Very strong evidence supporting the conclusion.

75–89%
Strong evidence with only minor uncertainty.

60–74%
Moderate evidence. Some information is limited.

40–59%
Limited evidence. More reviews or verification are recommended.

20–39%
Very limited or conflicting evidence.

0–19%
Insufficient evidence for a reliable conclusion.

Trust Score and Confidence are independent.

A station may have:
Trust Score 90 with Confidence 45 if it is new.
Trust Score 30 with Confidence 92 if there is strong evidence it is suspicious.

Never make Confidence automatically equal to the Trust Score.
Always format your station analysis exactly like this:
Station Source:

Trust Score:
/100

Classification:

Confidence:
/100

Evidence Summary:

Reasons:
•
•
•

Recommendation:
Reasons:
•
•
•

Recommendation:

Before giving the final verdict, think like an EV charging fraud investigator.

Your goal is to protect EV drivers from fake, misleading, duplicate, or suspicious charging stations.

Use every piece of available information together before making a decision.

Look for:
• Whether many reviews were posted within a very short period of time compared to the station's age.
• Fake or unrealistic station names
• Duplicate station names in nearby areas
• Extremely high or extremely low charging prices
• Impossible power outputs
• Reviews that look copied, spam, or AI-generated
• Ratings that do not match the written reviews
• Large numbers of reports
• Multiple reviews posted within a very short period
• Very few reviews combined with extremely high ratings
• Missing information ONLY if EVPlug normally stores that information.
• Whether the station source is Google Listed or Community Added.
• Whether the station information appears internally consistent.
Look for unusual behaviour such as:

• Many 5-star reviews posted within minutes of each other.
• Multiple reviews using nearly identical wording.
• Reports submitted immediately after many positive reviews.
• Prices that are far outside the normal range for similar stations.
• Duplicate stations with nearly identical information.
• Very old stations that still have almost no reviews.
• Community stations pretending to be official charging operators.

Use these only as indicators.
Never treat a single indicator as proof of fraud.
Never say a station is definitely fake.

Instead classify it as:
• Likely Genuine
• Needs Verification
• Potentially Suspicious

Always explain WHY.

If there is not enough evidence, clearly say that more reviews or reports are needed before making a stronger conclusion.

Do not guess missing facts.
If no station has been provided, continue behaving as the normal EV AI assistant.
User message: $message
''',
);

  if (!mounted) return;
setState(() {
  _aiReply = response;
});
  } catch (e) {
  if (!mounted) return;

  setState(() {
    _aiReply = 'Something went wrong. Please try again.';
  });
} finally {
  if (mounted) {
    setState(() {
      _isLoading = false;
    });

     _scrollToBottom();
  }
}
}

List<Map<String, dynamic>> _filterStationsForQuickAction(
  List<Map<String, dynamic>> stations,
  String actionType,
) {
  if (_currentPosition == null) {
    return stations.take(8).toList();
  }

  final userLat = _currentPosition!.latitude;
  final userLng = _currentPosition!.longitude;

  final withDistance = stations.map((s) {
    final lat = double.tryParse(s['latitude']?.toString() ?? '');
    final lng = double.tryParse(s['longitude']?.toString() ?? '');
    double? distance;
    if (lat != null && lng != null) {
      distance = EVStationService.distanceKm(userLat, userLng, lat, lng);
    }
    return Map<String, dynamic>.from(s)..['_distance'] = distance;
  }).toList();

  if (actionType == 'Fast Charger') {
    withDistance.removeWhere((s) {
      final power = double.tryParse(s['power']?.toString() ?? '');
      return power == null;
    });

    withDistance.sort((a, b) {
      final powerA = double.tryParse(a['power']?.toString() ?? '') ?? 0;
      final powerB = double.tryParse(b['power']?.toString() ?? '') ?? 0;
      final powerDiff = powerB.compareTo(powerA);
      if (powerDiff != 0) return powerDiff;
      final distA = a['_distance'] as double? ?? double.infinity;
      final distB = b['_distance'] as double? ?? double.infinity;
      return distA.compareTo(distB);
    });

    return withDistance.take(8).toList();
  }

  if (actionType == 'Cheapest') {
    withDistance.removeWhere((s) {
      final price = double.tryParse(s['price']?.toString() ?? '');
      return price == null;
    });

    withDistance.sort((a, b) {
      final priceA = double.tryParse(a['price']?.toString() ?? '') ?? double.infinity;
      final priceB = double.tryParse(b['price']?.toString() ?? '') ?? double.infinity;
      final priceDiff = priceA.compareTo(priceB);
      if (priceDiff != 0) return priceDiff;
      final distA = a['_distance'] as double? ?? double.infinity;
      final distB = b['_distance'] as double? ?? double.infinity;
      return distA.compareTo(distB);
    });

    final estimatedRange = _estimatedRangeKm ?? 0;
    final batteryPercent = _batteryPercentage ?? 0;
    final remainingRange = estimatedRange * batteryPercent / 100;
    final safetyReserve = estimatedRange * 0.15;
    final reachableRange = remainingRange - safetyReserve;

    return withDistance.where((s) {
      final dist = s['_distance'] as double? ?? double.infinity;
      return dist <= reachableRange;
    }).take(8).toList();
  }

  return stations.take(8).toList();
}

@override
Widget build(BuildContext context) {
final remainingRange = _remainingRangeKm;


return Scaffold(
  backgroundColor: const Color(0xFF030712),
  appBar: AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        Navigator.pop(context);
      },
    ),
    elevation: 0,
    backgroundColor: const Color(0xFF030712),
    centerTitle: true,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00FFAA).withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF00FFAA).withOpacity(.45),
            ),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Color(0xFF00FFAA),
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'EV AI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    ),
  ),
  body: SafeArea(
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Where would you like to go today?',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
             const SizedBox(height: 20),

const _AiDevelopmentBanner(),

const SizedBox(height: 15),

_vehicleContextCard(),
                const SizedBox(height: 15),
                _batteryCard(remainingRange),
                const SizedBox(height: 25),
               


               Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF111827),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    children: [
      TextField(
        controller: _manualLocationController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.my_location,
            color: Color(0xFF00FFAA),
          ),
          hintText: _currentPosition == null
              ? 'Enter current location'
              : 'Phone location selected',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1F2937),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isGettingLocation ? null : _getCurrentLocation,
          icon: const Icon(Icons.gps_fixed),
          label: Text(
            _isGettingLocation
                ? 'Getting location...'
                : 'Use My Current Location',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00FFAA),
            side: const BorderSide(color: Color(0xFF00FFAA)),
          ),
        ),
      ),

      const SizedBox(height: 12),

      TextField(
        controller: _destinationController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.location_on,
            color: Color(0xFF00FFAA),
          ),
          hintText: 'Enter destination',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF1F2937),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  final manualLocation =
                      _manualLocationController.text.trim();
                  final destination =
                      _destinationController.text.trim();

                  if (_currentPosition == null &&
                      manualLocation.isEmpty) {
                    setState(() {
                      _aiReply =
                          'Please use your current location or enter it manually.';
                    });
                    _scrollToBottom();
                    return;
                  }

                  if (destination.isEmpty) {
                    setState(() {
                      _aiReply = 'Please enter your destination.';
                    });
                    _scrollToBottom();
                    return;
                  }
final startLocation = _currentPosition != null
    ? 'Phone location: Latitude ${_currentPosition!.latitude}, Longitude ${_currentPosition!.longitude}'
    : manualLocation;

Map<String, dynamic>? route;
List<Map<String, dynamic>> googleRouteStations = [];

if (_currentPosition != null) {
  try {
    route = await EVRouteService.getRoute(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      destination: destination,
    );
  } catch (_) {
    route = null;
  }

  if (route != null) {
    googleRouteStations =
        await EVStationService.fetchStationsAlongRoute(
      encodedPolyline: route['polyline'] ?? '',
      searchRadius: 5000,
    );
  }
}

final googleStationsForAI =
    EVStationService.googleStationsForAI(
  googleRouteStations,
);
final communitySnapshot =
    await FirebaseFirestore.instance
        .collection('charging_stations')
        .get();

final communityStations =
    communitySnapshot.docs.map((doc) {
  final data = doc.data();

  return {
    'stationName':
        data['stationName'] ?? 'Unknown',

    'location':
        data['location'] ?? 'Unknown',

    'latitude':
        data['latitude'],

    'longitude':
        data['longitude'],

    'rating':
        data['averageRating'] ??
            data['rating'],

    'reviewCount':
        data['reviewCount'],

    'price':
        data['price'],

    'powerOutput':
        data['powerOutput'],

    'source':
        'EVPlug Community',

    'placeId':
        doc.id,
  };
}).toList();

final allRouteStations = [
  ...googleStationsForAI,
  ...communityStations,
];

final batteryPercent = _batteryPercentage ?? 0;
final estimatedRange = _estimatedRangeKm ?? 0;
final remainingRange = estimatedRange * batteryPercent / 100;
final safetyReserve = estimatedRange * 0.15;
final reachableRange = remainingRange - safetyReserve;
final destinationDistance = route?['distanceKm'] ?? 0;
final chargingRequired = destinationDistance > reachableRange;

final reachableStations = allRouteStations.where((s) {
  final dist = s['distanceKm'] ?? double.infinity;
  return dist <= reachableRange;
}).toList();

final stationData =
    EVStationService.stationsToAIJson(
  reachableStations.isNotEmpty ? reachableStations : allRouteStations,
);
debugPrint('ROUTE DISTANCE: ${route?['distanceKm']} km');
debugPrint('ROUTE DURATION: ${route?['duration']}');
debugPrint('ROUTE POLYLINE: ${route?['polyline']}');

// GET GOOGLE + EVPLUG STATIONS




// SEND ACTUAL DATA TO GEMINI
_messageController.text = '''
I want to travel from:

START:
$startLocation

DESTINATION:
$destination

GOOGLE ROAD ROUTE:
Distance: ${route?['distanceKm'] ?? 'Unknown'} km
Duration: ${route?['duration'] ?? 'Unknown'}

TRIP ANALYSIS:
Estimated full range: ${estimatedRange.toStringAsFixed(0)} km
Current battery: ${batteryPercent.toStringAsFixed(0)}%
Remaining range: ${remainingRange.toStringAsFixed(1)} km
Safety reserve: ${safetyReserve.toStringAsFixed(1)} km
Reachable range: ${reachableRange.toStringAsFixed(1)} km
Destination distance: ${destinationDistance.toStringAsFixed(1)} km
Charging required: $chargingRequired

CHARGING STATIONS AVAILABLE IN EVPLUG:
$stationData

IMPORTANT:

Use the charging station data provided above.

The station data contains:
- Google-listed stations
- EVPlug Community stations

Only use stations that are actually present in the data.

DO NOT invent:
- station names
- addresses
- distances
- prices
- charging speeds
- connector types

If a field is missing, write "Not available".

Create an ESTIMATED EV TRIP PLAN.

Show the most useful charging stations in travel order from the starting location toward the destination.

For every station show:

1. Station name
2. Source
3. Location
4. Distance
5. Charging speed if available
6. Price if available
7. Rating if available

Clearly identify the source as:
Google
or
EVPlug Community

Live charger availability is NOT connected yet.

Do NOT reject the trip plan because live availability is unavailable.

Do NOT tell me to check Google Maps instead of using the station data supplied above.

Return:

ESTIMATED TRIP PLAN

Start:
Destination:

Charging stops:

1.
Station name:
Source:
Location:
Distance:
Charging speed:
Price:
Rating:

2.
Station name:
Source:
Location:
Distance:
Charging speed:
Price:
Rating:

Keep the answer concise.
''';

await _sendMessage();
                },
          icon: const Icon(Icons.route),
          label: const Text(
            'Plan Trip',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFAA),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
       ],
  
  ),
),

const SizedBox(height: 30),

const Text(
  'Quick Actions',
  style: TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
_QuickCard(
  Icons.flash_on,
  'Fast Charger',
  () => _sendQuickAction('Fast Charger'),
),
_QuickCard(
  Icons.currency_rupee,
  'Cheapest',
  () => _sendQuickAction('Cheapest'),
),
_QuickCard(
  Icons.star,
  'Best Station',
  () => _sendQuickAction('Best Station'),
),
_QuickCard(
  Icons.alt_route,
  'On Route',
  () => _sendQuickAction('On Route'),
),
                  ],
                ),
                const SizedBox(height: 25),
                const Text(
                  'Map',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition == null
                            ? const LatLng(26.9124, 75.7873)
                            : LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                        zoom: 13,
                      ),
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: MapType.normal,
                      onMapCreated: (controller) {},
                    ),
                  ),
                ),
                const SizedBox(height: 25),
               if (_isLoading)
  const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: _AiThinkingBubble(),
  ),
                if (_aiReply.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00FFAA).withOpacity(.20),
                      ),
                     ),
                     child: MarkdownBody(
                       data: _aiReply,
                       styleSheet: MarkdownStyleSheet(
                         p: const TextStyle(
                           color: Colors.white,
                           height: 1.4,
                         ),
                         strong: const TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                         ),
                         blockSpacing: 8,
                       ),
                     ),
                   ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _sendMessage();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Ask EV AI...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF00FFAA),
                child: IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);


}

Widget _vehicleContextCard() {
final rangeText = _estimatedRangeKm == null
? 'Add estimated range in Profile'
: '${_estimatedRangeKm!.toStringAsFixed(0)} km estimated full range';


return Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF111827),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF00FFAA).withOpacity(.25),
    ),
  ),
  child: _isProfileLoading
      ? const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00FFAA),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading vehicle details...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.electric_car,
                  color: Color(0xFF00FFAA),
                ),
                SizedBox(width: 8),
                Text(
                  'VEHICLE CONTEXT',
                  style: TextStyle(
                    color: Color(0xFF00FFAA),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _carName.isEmpty ? 'Car name not added' : _carName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _vehicleNumber.isEmpty
                  ? 'Vehicle number not added'
                  : _vehicleNumber,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 5),
            Text(
              rangeText,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
);


}

Widget _batteryCard(double? remainingRange) {
final remainingText = remainingRange == null
? 'Enter battery percentage to calculate remaining range'
: '${remainingRange.toStringAsFixed(1)} km remaining range';


return Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF111827),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'BATTERY STATUS',
        style: TextStyle(
          color: Color(0xFF00FFAA),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _batteryController,
        keyboardType: TextInputType.number,
        onChanged: _updateBatteryPercentage,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Enter battery percentage (0 - 100)',
          hintStyle: const TextStyle(color: Colors.grey),
          suffixText: '%',
          suffixStyle: const TextStyle(color: Color(0xFF00FFAA)),
          filled: true,
          fillColor: const Color(0xFF1F2937),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        remainingText,
        style: TextStyle(
          color: remainingRange == null
              ? Colors.white60
              : const Color(0xFF00FFAA),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),

const Text(
  'Range is an estimate. AC, high speed, hard acceleration, traffic, hills, weather, and heavy load can reduce real range. Keep at least 15% battery or 20 km as a safety reserve.',
  style: TextStyle(
    color: Colors.white54,
    fontSize: 12,
    height: 1.35,
  ),
),
    ],
  ),
);


}
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickCard(this.icon, this.title, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00FFAA)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
class _AiThinkingBubble extends StatefulWidget {
  const _AiThinkingBubble();

  @override
  State<_AiThinkingBubble> createState() => _AiThinkingBubbleState();
}

class _AiThinkingBubbleState extends State<_AiThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FFAA).withOpacity(.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFF00FFAA),
            size: 18,
          ),
          const SizedBox(width: 10),
          const Text(
            'EV AI is thinking',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final activeDot =
                      ((_controller.value * 3).floor() % 3) == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: activeDot ? 8 : 5,
                    height: activeDot ? 8 : 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FFAA),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
class _AiDevelopmentBanner extends StatelessWidget {
  const _AiDevelopmentBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00FFAA).withOpacity(.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Color(0xFF00FFAA),
            size: 25,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EV AI is currently in development',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Smart charging intelligence is coming soon.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}