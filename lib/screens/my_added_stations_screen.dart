// lib/screens/my_added_stations_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyAddedStationsScreen extends StatelessWidget {
  const MyAddedStationsScreen({super.key});

  static const Color backgroundColor = Color(0xFF030712);
  static const Color cardColor = Color(0xFF111827);
  static const Color accentColor = Color(0xFF00FFAA);

  Future<void> _confirmAndDeleteStation(
    BuildContext context,
    String stationId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: const Text(
            'Remove Station?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This station will be permanently removed.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('charging_stations')
          .doc(stationId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station removed successfully.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove station: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('My Added Stations'),
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Please log in to view your added stations.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('My Added Stations'),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance
    .collection('charging_stations')
    .where('addedByUid', isEqualTo: currentUser.uid)
    .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your stations.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          final stations = List<QueryDocumentSnapshot>.from(
  snapshot.data?.docs ?? [],
);

stations.sort((a, b) {
  final aData = a.data() as Map<String, dynamic>;
  final bData = b.data() as Map<String, dynamic>;

  final Timestamp? aTime = aData['createdAt'];
  final Timestamp? bTime = bData['createdAt'];

  if (aTime == null || bTime == null) return 0;

  return bTime.millisecondsSinceEpoch
      .compareTo(aTime.millisecondsSinceEpoch);
});

         if (stations.isEmpty) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.ev_station_outlined,
            size: 80,
            color: Color(0xFF00FFAA),
          ),
          SizedBox(height: 20),
          Text(
            "No Stations Added Yet",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "You haven't added any charging stations.\nAdd your first station and help the EV community.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final stationDoc = stations[index];
              final data = stationDoc.data() as Map<String, dynamic>;
              final Timestamp? createdAt = data['createdAt'];

              String addedDate = "Unknown";

              if (createdAt != null) {
                final date = createdAt.toDate();
                addedDate = "${date.day}/${date.month}/${date.year}";
              }

              final stationName =
                  (data['stationName'] ?? 'Unnamed Station').toString();
              final location = (data['location'] ?? 'Location unavailable')
                  .toString();
              final powerOutput =
                  (data['powerOutput'] ?? 'Not specified').toString();
              final price = (data['price'] ?? 'Not specified').toString();

             

              return Card(
                color: cardColor,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: accentColor.withOpacity(0.16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stationName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _infoRow(
                              icon: Icons.location_on_outlined,
                              text: location,
                            ),
                            const SizedBox(height: 6),
                            _infoRow(
                              icon: Icons.bolt_outlined,
                              text: '$powerOutput kW',
                            ),
                            const SizedBox(height: 6),
                                                  _infoRow(
                              icon: Icons.currency_rupee,
                              text: '₹$price per kWh',
                            ),
                            const SizedBox(height: 6),
                            _infoRow(
                              icon: Icons.calendar_today_outlined,
                              text: 'Added on $addedDate',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove station',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          _confirmAndDeleteStation(
                            context,
                            stationDoc.id,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: accentColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}