import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 Future<void> submitReview({
  required bool isGoogle,
  required String stationId,
  required int rating,
  required String review,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final reviewData = {
    "rating": rating,
    "review": review.trim(),
    "createdAt": FieldValue.serverTimestamp(),
  };

  if (isGoogle) {
    await _firestore
        .collection("google_station_reviews")
        .doc(stationId)
        .collection("reviews")
        .doc(user.uid)
        .set(reviewData);
  } else {
    await _firestore
        .collection("charging_stations")
        .doc(stationId)
        .collection("reviews")
        .doc(user.uid)
        .set(reviewData);
  }

  // Update average rating and review count
  await _updateStationStats(
    isGoogle: isGoogle,
    stationId: stationId,
  );
}
    Future<QuerySnapshot<Map<String, dynamic>>> getReviews({
  required bool isGoogle,
  required String stationId,
}) {
  if (isGoogle) {
    return _firestore
        .collection("google_station_reviews")
        .doc(stationId)
        .collection("reviews")
        .orderBy("createdAt", descending: true)
        .get();
  }

  return _firestore
      .collection("charging_stations")
      .doc(stationId)
      .collection("reviews")
      .orderBy("createdAt", descending: true)
      .get();
}  

        Future<void> deleteReview({
  required bool isGoogle,
  required String stationId,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  if (isGoogle) {
  await _firestore
      .collection("google_station_reviews")
      .doc(stationId)
      .collection("reviews")
      .doc(user.uid)
      .delete();
} else {
  await _firestore
      .collection("charging_stations")
      .doc(stationId)
      .collection("reviews")
      .doc(user.uid)
      .delete();
}

// Add this here
await _updateStationStats(
  isGoogle: isGoogle,
  stationId: stationId,
);
}
        Future<bool> hasReviewed({
  required bool isGoogle,
  required String stationId,
}) async {
  final user = _auth.currentUser;
  if (user == null) return false;

  DocumentSnapshot doc;

  if (isGoogle) {
    doc = await _firestore
        .collection("google_station_reviews")
        .doc(stationId)
        .collection("reviews")
        .doc(user.uid)
        .get();
  } else {
    doc = await _firestore
        .collection("charging_stations")
        .doc(stationId)
        .collection("reviews")
        .doc(user.uid)
        .get();
  }

  return doc.exists;
}

Future<Map<String, dynamic>> getStationAiData({
  required bool isGoogle,
  required String stationId,
}) async {
  final reviews = await getReviews(
    isGoogle: isGoogle,
    stationId: stationId,
  );

  final List<Map<String, dynamic>> reviewList = [];

  double totalRating = 0;

  for (final doc in reviews.docs) {
    final data = doc.data();

    reviewList.add({
      "rating": data["rating"] ?? 0,
      "review": data["review"] ?? "",
      "createdAt": data["createdAt"]?.toString() ?? "",
    });

    totalRating += (data["rating"] ?? 0).toDouble();
  }

  final averageRating = reviewList.isEmpty
      ? 0.0
      : totalRating / reviewList.length;

final reportSnapshot = await _firestore
    .collection("station_reports")
    .where("stationId", isEqualTo: stationId)
    .get();

final List<Map<String, dynamic>> reportList = [];

for (final doc in reportSnapshot.docs) {
  final data = doc.data();

  reportList.add({
    "reason": data["reason"] ?? "",
    "customReason": data["customReason"] ?? "",
    "createdAt": data["createdAt"]?.toString() ?? "",
  });
}
 return {
  "averageRating": averageRating,
  "reviewCount": reviewList.length,
  "reviews": reviewList,
  "reportCount": reportList.length,
  "reports": reportList,
};
}
Future<void> _updateStationStats({
  required bool isGoogle,
  required String stationId,
}) async {
  QuerySnapshot<Map<String, dynamic>> snapshot;

  if (isGoogle) {
    snapshot = await _firestore
        .collection("google_station_reviews")
        .doc(stationId)
        .collection("reviews")
        .get();
  } else {
    snapshot = await _firestore
        .collection("charging_stations")
        .doc(stationId)
        .collection("reviews")
        .get();
  }

  double total = 0;

  for (var doc in snapshot.docs) {
    total += (doc["rating"] ?? 0).toDouble();
  }

  final count = snapshot.docs.length;
  final average = count == 0 ? 0.0 : total / count;

  if (!isGoogle) {
    await _firestore
        .collection("charging_stations")
        .doc(stationId)
        .update({
      "reviewCount": count,
      "averageRating": average,
    });
  }
}
}