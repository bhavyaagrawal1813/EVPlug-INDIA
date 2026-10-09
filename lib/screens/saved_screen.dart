import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  static const Color cardColor = Color(0xFF111827);
  static const Color accentColor = Color(0xFF00FFAA);
  static const Color communityColor = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(
          child: Text(
            "Please log in to view your saved stations.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF030712),

      appBar: AppBar(
        backgroundColor: const Color(0xFF030712),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Saved Chargers",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("savedStations")
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Unable to load your saved stations.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No saved stations yet.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,

            itemBuilder: (context, index) {
              final doc = docs[index];

              final station = doc.data() as Map<String, dynamic>;

              final isCommunity = station["source"] == "community" ||
                  station["source"] == "user";

              final accent =
                  isCommunity ? communityColor : accentColor;

              final lat = station["latitude"];
              final lng = station["longitude"];

              final hasCoordinates =
                  lat is num && lng is num;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.18),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station["name"] ?? "Station",

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(
                            Icons.bookmark,
                            color: accentColor,
                          ),

                          onPressed: () async {
                            // Delete by document id so the removal always
                            // targets the document that was created.
                            await doc.reference.delete();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      station["address"] ?? "No address",
                      style: const TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      isCommunity
                          ? "Community Added"
                          : "Google Listed",
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),

                    if (hasCoordinates) ...[
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.navigation),
                          label: const Text("Navigate"),
                          onPressed: () async {
                            final Uri url = Uri.parse(
                              "https://www.google.com/maps/dir/?api=1"
                              "&destination=$lat,$lng",
                            );

                            try {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Could not open navigation.",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
