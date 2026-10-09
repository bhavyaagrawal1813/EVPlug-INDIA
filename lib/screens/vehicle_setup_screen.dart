
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';

class VehicleSetupScreen extends StatefulWidget {
  const VehicleSetupScreen({super.key});

  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  final TextEditingController vehicleNumberController =
      TextEditingController();

  final TextEditingController vehicleNameController =
      TextEditingController();

  final TextEditingController vehicleRangeController =
      TextEditingController();

  bool loading = false;

  Future<void> saveVehicle() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final vehicleNumber = vehicleNumberController.text.trim();
    final vehicleName = vehicleNameController.text.trim();
    final rangeText = vehicleRangeController.text.trim();

    if (vehicleNumber.isEmpty ||
        vehicleName.isEmpty ||
        rangeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all required fields",
          ),
        ),
      );
      return;
    }

    final range = int.tryParse(rangeText);
    if (range == null || range <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Estimated range must be a positive number"),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "vehicleNumber": vehicleNumber,
        "vehicleName": vehicleName,
        "carName": vehicleName,
        "estimatedRangeKm": range,
        "estimatedRange": range.toString(),
        "vehicleAdded": true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    vehicleNumberController.dispose();
    vehicleNameController.dispose();
    vehicleRangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030708),

      appBar: AppBar(
        backgroundColor: const Color(0xFF030708),
        elevation: 0,
        title: const Text(
          "Setup Your EV",
          style: TextStyle(
            color: Color(0xFF52FFC8),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.ev_station,
                    size: 80,
                    color: Color(0xFF52FFC8),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "EVPLUG",
                    style: TextStyle(
                      color: Color(0xFF52FFC8),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "One-time vehicle setup",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // VEHICLE NUMBER
            // VEHICLE NUMBER
TextField(
  controller: vehicleNumberController,

  onChanged: (value) {
    vehicleNumberController.value = TextEditingValue(
      text: value.toUpperCase(),
      selection: TextSelection.collapsed(
        offset: value.toUpperCase().length,
      ),
    );
  },

  style: const TextStyle(
    color: Colors.white,
  ),
  decoration: const InputDecoration(
    hintText: "Vehicle Number (Required)",
    hintStyle: TextStyle(
      color: Colors.white54,
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Color(0xFF52FFC8),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Color(0xFF52FFC8),
        width: 2,
      ),
    ),
  ),
),

            const SizedBox(height: 15),

            // VEHICLE NAME
            TextField(
  controller: vehicleNameController,

  onChanged: (value) {
    vehicleNameController.value = TextEditingValue(
      text: value.toUpperCase(),
      selection: TextSelection.collapsed(
        offset: value.toUpperCase().length,
      ),
    );
  },

  style: const TextStyle(
    color: Colors.white,
  ),
  decoration: const InputDecoration(
    hintText: "Vehicle Name (Required)",
    hintStyle: TextStyle(
      color: Colors.white54,
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Color(0xFF52FFC8),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Color(0xFF52FFC8),
        width: 2,
      ),
    ),
  ),
),
            const SizedBox(height: 15),

            // RANGE
            TextField(
           controller: vehicleRangeController,
            keyboardType: TextInputType.number,
             inputFormatters: [
             FilteringTextInputFormatter.digitsOnly,
            ],
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                hintText:
                    "Estimated Range in KM (Required)",
                hintStyle: TextStyle(
                  color: Colors.white54,
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF52FFC8),
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF52FFC8),
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Note: Range is user estimated, not manufacturer claimed",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF52FFC8),
                  foregroundColor:
                      Colors.black,
                ),
                onPressed:
                    loading ? null : saveVehicle,
                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                      )
                    : const Text(
                        "Save & Continue",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
