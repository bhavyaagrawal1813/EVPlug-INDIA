import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/review_service.dart';
import '../utils/map_utils.dart';
import 'ev_ai_screen.dart';
import '../services/ev_station_service.dart';
import '../services/gemini_service.dart';
class StationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> station;

  const StationDetailsScreen({
    super.key,
    required this.station,
  });

  @override
  State<StationDetailsScreen> createState() =>
      _StationDetailsScreenState();
}

class _StationDetailsScreenState
    extends State<StationDetailsScreen> {
  static const Color backgroundColor =
      Color(0xFF030712);

  static const Color cardColor =
      Color(0xFF111827);

  static const Color accentColor =
      Color(0xFF00FFAA);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final ReviewService _reviewService = ReviewService();

  final TextEditingController _reviewController =
    TextEditingController();

int _selectedRating = 5;
  
    List<Map<String, dynamic>> _reviews = [];

double _averageRating = 0;

int _reviewCount = 0;

int _fiveStar = 0;
int _fourStar = 0;
int _threeStar = 0;
int _twoStar = 0;
int _oneStar = 0;

bool _loadingReviews = true;
bool _hasReviewed = false;
        String? _selectedReportReason;

final TextEditingController _reportController =
    TextEditingController();

final List<String> _reportReasons = [
  "Incorrect location",
  "Station permanently closed",
  "Charger not working",
  "Wrong charging price",
  "Duplicate station",
  "Fake station",
  "Other",
];


  bool _isSaved = false;
  bool _loadingSave = true;
Map<String, dynamic>? googleDetails;
bool isLoadingDetails = false;
  Map<String, dynamic> get station =>
      widget.station;

  bool get isGoogle =>
      station["source"] == "google";

  bool get isCommunity =>
      station["source"] == "community" ||
      station["source"] == "user";

  String get stationId {
    if (isGoogle) {
      return station["place_id"] ?? "";
    }
    return station["id"] ?? "";
  }

  String get stationName =>
      station["name"] ??
      station["stationName"] ??
      "Charging Station";

  String get address =>
      station["vicinity"] ??
      station["location"] ??
      "Address unavailable";

  double get distanceKm =>
      (station["distanceKm"] ?? 0).toDouble();

  double? get latitude {
    if (station["geometry"] != null) {
      return station["geometry"]["location"]["lat"];
    }
    return station["latitude"];
  }

  double? get longitude {
    if (station["geometry"] != null) {
      return station["geometry"]["location"]["lng"];
    }
    return station["longitude"];
  }

 @override
void initState() {
  super.initState();
  _checkSaved();
  _loadReviews();
  _checkIfReviewed();
  loadGoogleDetails();
}
Future<void> loadGoogleDetails() async {
  if (!isGoogle) return;

  final placeId = station["place_id"];

  if (placeId == null) return;

  setState(() {
    isLoadingDetails = true;
  });

  try {
    googleDetails =
        await EVStationService.fetchPlaceDetails(placeId);
  } catch (e) {
    debugPrint(e.toString());
  }

  if (mounted) {
    setState(() {
      isLoadingDetails = false;
    });
  }
}

        Future<void> _loadReviews() async {
  final snapshot = await _reviewService.getReviews(
    isGoogle: isGoogle,
    stationId: stationId,
  );

  _reviews = [];

  _fiveStar = 0;
  _fourStar = 0;
  _threeStar = 0;
  _twoStar = 0;
  _oneStar = 0;

  double total = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    _reviews.add(data);

    final rating = data["rating"] ?? 0;

    total += rating;

    switch (rating) {
      case 5:
        _fiveStar++;
        break;
      case 4:
        _fourStar++;
        break;
      case 3:
        _threeStar++;
        break;
      case 2:
        _twoStar++;
        break;
      case 1:
        _oneStar++;
        break;
    }
  }

  _reviewCount = _reviews.length;

  _averageRating =
      _reviewCount == 0 ? 0 : total / _reviewCount;

  if (mounted) {
    setState(() {
      _loadingReviews = false;
    });
  }
}

Future<void> _checkIfReviewed() async {
  _hasReviewed = await _reviewService.hasReviewed(
    isGoogle: isGoogle,
    stationId: stationId,
  );

  if (mounted) {
    setState(() {});
  }
}
  Future<void> _checkSaved() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("savedStations")
        .doc(stationId)
        .get();

    if (!mounted) return;

    setState(() {
      _isSaved = doc.exists;
      _loadingSave = false;
    });
  }   Future<void> _toggleSave() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection("users")
        .doc(user.uid)
        .collection("savedStations")
        .doc(stationId);

    if (_isSaved) {
      await docRef.delete();
    } else {
      await docRef.set({
        "stationId": stationId,
        "name": stationName,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "source": station["source"],
        "savedAt": FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

    setState(() {
      _isSaved = !_isSaved;
    });
  }

  void _navigate() {
    if (latitude == null || longitude == null) return;

   MapUtils.openMap(
  latitude: latitude!,
  longitude: longitude!,
);
  }

  void _share() {
    final lat = latitude;
    final lng = longitude;
    final power = station["powerOutput"]?.toString() ?? "";
    final price = station["price"]?.toString() ?? "";

    final buffer = StringBuffer()
      ..writeln("EVPlug Station")
      ..writeln("Station: $stationName")
      ..writeln("Location: $address");
    if (power.isNotEmpty) buffer.writeln("Charging Power: $power kW");
    if (price.isNotEmpty) buffer.writeln("Price: ₹$price per kWh");
    if (lat != null && lng != null) {
      buffer.writeln("Google Maps: https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    }
    buffer.writeln("");
    buffer.writeln("Shared from EVPlug");

    final text = buffer.toString();

    Share.share(text, subject: stationName);
  }

   Future<void> _submitReport() async {
  try {
    if (_selectedReportReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a reason."),
        ),
      );
      return;
    }

    final user = _auth.currentUser;

    await _firestore.collection("station_reports").add({
      "stationId": stationId,
      "stationName": stationName,
      "source": station["source"],
      "reportedBy": user?.uid,
      "reason": _selectedReportReason,
      "customReason": _selectedReportReason == "Other"
          ? _reportController.text.trim()
          : "",
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    setState(() {
      _selectedReportReason = null;
      _reportController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report submitted successfully."),
      ),
    );
  } catch (e) {
    debugPrint(e.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Station Details",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Text(
              stationName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color:
                    accentColor.withOpacity(.12),
                borderRadius:
                    BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Icon(
                    isGoogle
                        ? Icons.verified
                        : Icons.people,
                    color: accentColor,
                    size: 18,
                  ),

                  const SizedBox(width: 8),

                  Text(
                   isGoogle
                   ? "⚡ Google"
                   : "🟢 Community",
                    style: const TextStyle(
                      color: accentColor,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            _sectionTitle("Location"),

            const SizedBox(height: 14),

            _infoTile(
              icon: Icons.location_on,
              title: "Address",
              value: address,
            ),

            const SizedBox(height: 14),

            _infoTile(
              icon: Icons.near_me,
              title: "Distance",
              value:
                  "${distanceKm.toStringAsFixed(1)} km away",
            ),

            const SizedBox(height: 28),
                       _sectionTitle("Rating"),

const SizedBox(height: 14),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(18),
  ),
  child: Row(
    children: [
      const Icon(
        Icons.star,
        color: Colors.amber,
        size: 32,
      ),

      const SizedBox(width: 16),

      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Text(
  isGoogle
      ? "${(googleDetails?["rating"] ?? station["rating"] ?? 0).toString()} / 5"
      : (_reviewCount == 0
          ? "No Ratings"
          : "${_averageRating.toStringAsFixed(1)} / 5"),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
),

          const SizedBox(height: 4),

         Text(
  isGoogle
      ? "${googleDetails?["user_ratings_total"] ?? station["user_ratings_total"] ?? 0} Reviews"
      : (_reviewCount == 1
          ? "1 Review"
          : "$_reviewCount Reviews"),
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 15,
  ),
),
        ],
      ),
    ],
  ),
),

            // Community ratings come from EVPlug reviews, so the
            // distribution is our own data and is worth showing.
            if (!isGoogle && _reviewCount > 0) ...[
              const SizedBox(height: 16),

              _ratingRow(5, _fiveStar),
              _ratingRow(4, _fourStar),
              _ratingRow(3, _threeStar),
              _ratingRow(2, _twoStar),
              _ratingRow(1, _oneStar),
            ],

            const SizedBox(height: 28),

            _sectionTitle("Charging Information"),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [

                  if (isCommunity &&
                      station["powerOutput"] != null)
                    _infoTile(
                      icon: Icons.flash_on,
                      title: "Power Output",
                      value: station["powerOutput"]
                          .toString(),
                    ),

                  if (isCommunity &&
                      station["powerOutput"] != null)
                    const SizedBox(height: 18),

                  if (isCommunity &&
                      station["price"] != null)
                    _infoTile(
                      icon: Icons.currency_rupee,
                      title: "Charging Price",
                      value: station["price"]
                          .toString(),
                    ),

                  if (isGoogle)
                    const Text(
                      "Charging information is not provided by Google Maps.",
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            _sectionTitle("Community Information"),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: isGoogle
                  ? const ListTile(
                      leading: Icon(
                        Icons.verified,
                        color: accentColor,
                      ),
                      title: Text(
                        "Verified by Google Maps",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    )
                  : _infoTile(
                      icon: Icons.calendar_today,
                      title: "Added On",
                      value: station["createdAt"] != null
                          ? (station["createdAt"]
                                  as Timestamp)
                              .toDate()
                              .toString()
                              .split(" ")
                              .first
                          : "Unknown",
                    ),
            ),

           const SizedBox(height: 28),

_sectionTitle("Actions"),

const SizedBox(height: 16),

Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: _navigate,
        icon: const Icon(Icons.navigation),
        label: const Text("Navigate"),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: ElevatedButton.icon(
        onPressed: _loadingSave ? null : _toggleSave,
        icon: Icon(
          _isSaved ? Icons.bookmark : Icons.bookmark_border,
        ),
        label: Text(
          _isSaved ? "Saved" : "Save",
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    ),
  ],
),

const SizedBox(height: 14),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: _share,
    icon: const Icon(Icons.share),
    label: const Text("Share"),
    style: ElevatedButton.styleFrom(
      backgroundColor: cardColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15),
    ),
  ),
),

const SizedBox(height: 14),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
   onPressed: () {
     if (!GeminiService.isEnabled) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text(
             'EV AI is temporarily unavailable. '
             'It will return in a future update.',
           ),
         ),
       );
       return;
     }

     Navigator.push(
   context,
   MaterialPageRoute(
     builder: (_) => EvAiScreen(
       station: station,
     ),
   ),
 );
     },
    icon: const Icon(Icons.psychology),
    label: const Text("Analyze Station"),
    style: ElevatedButton.styleFrom(
      backgroundColor: accentColor,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 15),
    ),
  ),
),

    const SizedBox(height: 24),

    DropdownButtonFormField<int>(
  initialValue: _selectedRating,
  dropdownColor: cardColor,
  decoration: InputDecoration(
    filled: true,
    fillColor: cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  items: List.generate(
    5,
    (index) => DropdownMenuItem(
      value: 5 - index,
      child: Text(
        "${5 - index} ★",
        style: const TextStyle(color: Colors.white),
      ),
    ),
  ),
  onChanged: (value) {
    setState(() {
      _selectedRating = value!;
    });
  },
),

const SizedBox(height: 12),

TextField(
  controller: _reviewController,
  maxLines: 3,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: "Write your review...",
    hintStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),

const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
   onPressed: () async {
    if (_reviewController.text.trim().isEmpty) return;

    await _reviewService.submitReview(
      isGoogle: isGoogle,
      stationId: stationId,
      rating: _selectedRating,
      review: _reviewController.text,
    );

    _reviewController.clear();

      await _loadReviews();
      await _checkIfReviewed();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Review submitted successfully"),
        ),
      );
    },
  child: Text(
  _hasReviewed ? "Update Review" : "Submit Review",
),
  ),
),

            const SizedBox(height: 24),

if (_loadingReviews)
  const Center(
    child: CircularProgressIndicator(
      color: accentColor,
    ),
  )
else if (_reviews.isEmpty)
  const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        "No reviews yet.\nBe the first to review!",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),
    ),
  )
else
  ..._reviews.map((review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              const CircleAvatar(
                backgroundColor: accentColor,
                child: Icon(
                  Icons.person,
                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  "EVPlug User",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

             Row(
  children: List.generate(
    5,
    (index) => Icon(
      index < (review["rating"] ?? 0)
          ? Icons.star
          : Icons.star_border,
      color: Colors.amber,
      size: 18,
    ),
  ),
),

            ],
          ),

          const SizedBox(height: 12),

          Text(
            review["review"] ?? "",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }),

          
            const SizedBox(height: 24),

       

            const SizedBox(height: 24),

          _sectionTitle("Report Station"),

const SizedBox(height: 14),

DropdownButtonFormField<String>(
  initialValue: _selectedReportReason,
  dropdownColor: cardColor,
  decoration: InputDecoration(
    filled: true,
    fillColor: cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  hint: const Text(
    "Select a reason",
    style: TextStyle(color: Colors.white70),
  ),
  items: _reportReasons.map((reason) {
    return DropdownMenuItem(
      value: reason,
      child: Text(
        reason,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedReportReason = value;
    });
  },
),

if (_selectedReportReason == "Other") ...[
  const SizedBox(height: 12),

  TextField(
    controller: _reportController,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: "Describe the issue...",
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    maxLines: 3,
  ),
],

const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
   onPressed: _submitReport,
    icon: const Icon(Icons.flag),
    label: const Text("Submit Report"),
  ),
),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: accentColor,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

   
   Widget _ratingRow(int stars, int count) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            "$stars",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),

        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 16,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: LinearProgressIndicator(
            value: _reviewCount == 0
                ? 0
                : count / _reviewCount,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor:
                const AlwaysStoppedAnimation(
              Colors.amber,
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 30,
          child: Text(
            "$count",
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      ],
    ),
  );
}
}
