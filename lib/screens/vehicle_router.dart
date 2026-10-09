import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'vehicle_setup_screen.dart';

class VehicleCheckRouter extends StatelessWidget {
  const VehicleCheckRouter({super.key});

  Future<bool> hasCompletedVehicleSetup() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return false;
  }

  final userDoc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .get();

  if (!userDoc.exists) {
    return false;
  }

  final data = userDoc.data();

  if (data == null || data["vehicleAdded"] != true) {
    return false;
  }

  return true;
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasCompletedVehicleSetup(),

      builder: (context, snapshot) {

        // LOADING
        if (snapshot.connectionState ==
            ConnectionState.waiting) {

          return const Scaffold(
            backgroundColor: Color(0xFF030708),

            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  Icon(
                    Icons.ev_station,
                    color: Color(0xFF52FFC8),
                    size: 85,
                  ),

                  SizedBox(height: 15),

                  Text(
                    "EVPLUG",
                    style: TextStyle(
                      color: Color(0xFF52FFC8),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Checking your EV profile...",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),

                  SizedBox(height: 25),

                  CircularProgressIndicator(
                    color: Color(0xFF52FFC8),
                  ),
                ],
              ),
            ),
          );
        }

        // ERROR (UNCHANGED)
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF030708),
            body: Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        final hasVehicle = snapshot.data ?? false;

        // ROUTING
        if (hasVehicle) {
          return const HomeScreen();
        } else {
          return const VehicleSetupScreen();
        }
      },
    );
  }
}