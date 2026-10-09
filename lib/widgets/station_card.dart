import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/station_details_screen.dart';

/// Visual identity shared by the official and community station lists.
class StationSourceStyle {
  static const Color official = Color(0xFF00FFAA);
  static const Color community = Color(0xFF00E5FF);

  const StationSourceStyle._();
}

/// Builds the Firestore document id used for a saved station.
///
/// StationDetailsScreen uses the same id, so saving from either place
/// updates the same document.
String stationSavedDocId(Map<String, dynamic> station) {
  return (station['place_id'] ??
          station['id'] ??
          station['name'] ??
          '')
      .toString();
}

/// Formats a distance for display. Returns metres below 1 km so short
/// distances are not shown as "0.0 km".
String formatStationDistance(double? distanceKm) {
  if (distanceKm == null) return "Distance unavailable";

  if (distanceKm < 1) {
    return "${(distanceKm * 1000).round()} m away";
  }

  return "${distanceKm.toStringAsFixed(1)} km away";
}

/// A single station row.
///
/// The card sizes itself to its content instead of being forced into a
/// fixed grid cell, so a community station with power and price details
/// can never overflow into the row below it.
class StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isCommunity;
  final bool usingFallbackLocation;
  final void Function(double lat, double lng) onNavigate;

  const StationCard({
    super.key,
    required this.station,
    required this.isCommunity,
    required this.onNavigate,
    this.usingFallbackLocation = false,
  });

  Color get _accent =>
      isCommunity ? StationSourceStyle.community : StationSourceStyle.official;

  String get _ratingText {
    if (isCommunity) {
      final average = station['averageRating'];

      if (average is num && average > 0) {
        return "${average.toStringAsFixed(1)} ★";
      }

      return "No Rating";
    }

    final rating = station['rating'];

    return rating != null ? "$rating ★" : "No Rating";
  }

  String get _distanceText {
    if (usingFallbackLocation) {
      return "From default centre";
    }

    final distanceKm = station['distanceKm'];

    return formatStationDistance(
      distanceKm is double ? distanceKm : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lat = station['geometry']?['location']?['lat'];
    final lng = station['geometry']?['location']?['lng'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StationDetailsScreen(
              station: {
                ...station,
                "source": isCommunity ? "community" : "google",
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _accent.withValues(alpha: 0.22),
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCommunity
                          ? const [Color(0xFF00E5FF), Color(0xFF0091EA)]
                          : const [Color(0xFF00FFAA), Color(0xFF00E5FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCommunity ? Icons.people : Icons.bolt,
                    color: Colors.black,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        station['name'] ?? "EV Station",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      _SourceBadge(isCommunity: isCommunity),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                _DistancePill(text: _distanceText),
              ],
            ),

            const SizedBox(height: 14),

            _DetailsPanel(
              station: station,
              isCommunity: isCommunity,
              ratingText: _ratingText,
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _NavigateButton(
                    hasCoordinates: lat is num && lng is num,
                    accent: _accent,
                    onNavigate: () {
                      if (lat is num && lng is num) {
                        onNavigate(lat.toDouble(), lng.toDouble());
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _SaveButton(
                    docId: stationSavedDocId(station),
                    station: station,
                    isCommunity: isCommunity,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical list of station cards with consistent spacing.
class StationList extends StatelessWidget {
  final List<Map<String, dynamic>> stations;
  final bool isCommunity;
  final bool usingFallbackLocation;
  final String emptyMessage;
  final void Function(double lat, double lng) onNavigate;

  const StationList({
    super.key,
    required this.stations,
    required this.isCommunity,
    required this.onNavigate,
    this.usingFallbackLocation = false,
    this.emptyMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCommunity
        ? StationSourceStyle.community
        : StationSourceStyle.official;

    if (stations.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: stations
            .map(
              (station) => StationCard(
                station: station,
                isCommunity: isCommunity,
                usingFallbackLocation: usingFallbackLocation,
                onNavigate: onNavigate,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// A titled band that separates the official list from the community
/// list, including a live count of each.
class StationSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int count;
  final Key? sectionKey;
  final VoidCallback? onTap;

  const StationSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.count,
    this.sectionKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: sectionKey,
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_downward,
                  color: color.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final bool isCommunity;

  const _SourceBadge({required this.isCommunity});

  @override
  Widget build(BuildContext context) {
    final color = isCommunity
        ? StationSourceStyle.community
        : StationSourceStyle.official;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isCommunity ? "Community Added" : "Google Listed",
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DistancePill extends StatelessWidget {
  final String text;

  const _DistancePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF00FFAA).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF00FFAA),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isCommunity;
  final String ratingText;

  const _DetailsPanel({
    required this.station,
    required this.isCommunity,
    required this.ratingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                ratingText,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (!isCommunity) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "(${station['user_ratings_total'] ?? 0} Google reviews)",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          if (isCommunity) ...[
            _DetailRow(
              icon: Icons.flash_on,
              label: "Power",
              value: station['powerOutput'] != null
                  ? "${station['powerOutput']} kW"
                  : "Not specified",
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.currency_rupee,
              label: "Price",
              value: station['price'] != null
                  ? "₹${station['price']} per kWh"
                  : "Not specified",
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: "Location",
              value: station['vicinity'] ?? "Address unavailable",
            ),
          ] else
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: "Address",
              value: station['vicinity'] ?? "Address unavailable",
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 15),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigateButton extends StatelessWidget {
  final bool hasCoordinates;
  final Color accent;
  final VoidCallback onNavigate;

  const _NavigateButton({
    required this.hasCoordinates,
    required this.accent,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
        ),

        onPressed: hasCoordinates ? onNavigate : null,

        icon: Icon(
          hasCoordinates ? Icons.navigation : Icons.location_off,
          size: 18,
        ),

        label: Text(hasCoordinates ? "Navigate" : "No GPS"),
      ),
    );
  }
}

/// Save toggle backed by real Firestore state, so this card and the
/// Saved screen never disagree.
class _SaveButton extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> station;
  final bool isCommunity;

  const _SaveButton({
    required this.docId,
    required this.station,
    required this.isCommunity,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _isSaved = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  DocumentReference? _ref() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || widget.docId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedStations")
        .doc(widget.docId);
  }

  Future<void> _checkSaved() async {
    DocumentReference? ref;

    try {
      ref = _ref();
    } catch (e) {
      // Auth unavailable (signed out mid-session, for example).
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (ref == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await ref.get();

      if (mounted) {
        setState(() {
          _isSaved = doc.exists;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy || widget.docId.isEmpty) return;

    DocumentReference? ref;

    try {
      ref = _ref();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please log in to save stations."),
          ),
        );
      }
      return;
    }

    if (ref == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please log in to save stations."),
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);

    try {
      if (_isSaved) {
        await ref.delete();
      } else {
        await ref.set({
          "stationId": widget.docId,
          "name": widget.station['name'] ??
              widget.station['stationName'] ??
              "Station",
          "address": widget.station['vicinity'] ??
              widget.station['location'] ??
              "Address unavailable",
          "latitude": widget.station['geometry']?['location']?['lat'],
          "longitude": widget.station['geometry']?['location']?['lng'],
          "source": widget.isCommunity ? "community" : "google",
          "savedAt": FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        _isSaved = !_isSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved ? "Station saved" : "Removed from saved",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not update saved stations."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _isSaved
              ? const Color(0xFF00FFAA)
              : Colors.white,
          side: BorderSide(
            color: _isSaved
                ? const Color(0xFF00FFAA)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),

        onPressed: (_loading || _busy) ? null : _toggle,

        icon: (_loading || _busy)
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
              ),

        label: Text(_loading ? "..." : (_isSaved ? "Saved" : "Save")),
      ),
    );
  }
}
