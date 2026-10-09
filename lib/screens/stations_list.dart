import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class StationsListScreen extends StatefulWidget {
  const StationsListScreen({super.key});

  @override
  State<StationsListScreen> createState() =>
      _StationsListScreenState();
}

class _StationsListScreenState
    extends State<StationsListScreen> {
  Position? userPosition;

  @override
  void initState() {
    super.initState();
    getUserLocation();
  }

  // GET REAL USER LOCATION
  Future<void> getUserLocation() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return;

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position =
        await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      userPosition = position;
    });
  }

  // DISTANCE CALCULATOR
  double getDistance(double lat, double lng) {
    if (userPosition == null) return 999999;

    return Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      lat,
      lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),

      appBar: AppBar(
        title: const Text("Charging Stations"),
        backgroundColor: const Color(0xFF111827),
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("stations")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          var stations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: stations.length,
            itemBuilder: (context, index) {
              var data = stations[index];

              double lat = data["lat"] ?? 0;
              double lng = data["lng"] ?? 0;

              double distance = getDistance(lat, lng);

              // show only within 10km
             

              return Card(
                color: const Color(0xFF111827),
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(
                    data["name"] ?? "",
                    style: const TextStyle(
                        color: Colors.white),
                  ),
                  subtitle: Text(
                    "Power: ${data["power"]} kW\n"
                    "Price: ${data["price"]}\n"
                    "Distance: ${(distance / 1000).toStringAsFixed(2)} km",
                    style: const TextStyle(
                        color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.ev_station,
                    color: Color(0xFF00FFAA),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}