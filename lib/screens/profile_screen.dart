import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import 'my_added_stations_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController carNameController = TextEditingController();
  final TextEditingController vehicleNumberController =
      TextEditingController();
  final TextEditingController estimatedRangeController =
      TextEditingController();

  final Color backgroundColor = const Color(0xFF030712);
  final Color cardColor = const Color(0xFF111827);
  final Color accentColor = const Color(0xFF00FFAA);

  @override
  void dispose() {
    carNameController.dispose();
    vehicleNumberController.dispose();
    estimatedRangeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: cardColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            "Edit Name",
            style: TextStyle(color: accentColor),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter your name",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text("Name cannot be empty."),
                    ),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user == null) {
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .set(
                    {
                      "name": newName,
                    },
                    SetOptions(merge: true),
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  _showSnackBar("Name updated successfully.");
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Unable to update name. Please check your connection and try again.",
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showEditVehicleDialog(
    String currentCarName,
    String currentVehicleNumber,
    String currentRange,
  ) {
    carNameController.text = currentCarName;
    vehicleNumberController.text = currentVehicleNumber;
    estimatedRangeController.text = currentRange;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            "Edit Vehicle",
            style: TextStyle(color: accentColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: carNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Car Name",
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: vehicleNumberController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Vehicle Number",
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: estimatedRangeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.]'),
                    ),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Estimated Range (km)",
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final carName = carNameController.text.trim();
                final vehicleNumber =
                    vehicleNumberController.text.trim().toUpperCase();
                final estimatedRange =
                    estimatedRangeController.text.trim();

                if (carName.isEmpty ||
                    vehicleNumber.isEmpty ||
                    estimatedRange.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please fill all vehicle details.",
                      ),
                    ),
                  );
                  return;
                }

                if (double.tryParse(estimatedRange) == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Estimated range must be a valid number.",
                      ),
                    ),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user == null) {
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .set(
                    {
                      "carName": carName,
                      "vehicleNumber": vehicleNumber,
                      "estimatedRangeKm": estimatedRange,
                    },
                    SetOptions(merge: true),
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  _showSnackBar("Vehicle details updated successfully.");
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Unable to update vehicle. Please check your connection and try again.",
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      _showSnackBar("Unable to logout. Please try again.");
    }
  }

  Widget _buildProfileHeader({
    required String name,
    required String email,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: accentColor,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 45,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            name.isEmpty ? "EVPlug User" : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () {
              _showEditNameDialog(name);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit,
                  color: accentColor,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  "Edit Name",
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard({
    required String carName,
    required String vehicleNumber,
    required String estimatedRange,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: accentColor,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Vehicle Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _showEditVehicleDialog(
                    carName,
                    vehicleNumber,
                    estimatedRange,
                  );
                },
                icon: Icon(
                  Icons.edit,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildDetailRow(
            Icons.electric_car,
            "Car",
            carName.isEmpty ? "Not added" : carName,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.confirmation_number,
            "Vehicle Number",
            vehicleNumber.isEmpty ? "Not added" : vehicleNumber,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.battery_charging_full,
            "Estimated Range",
            estimatedRange.isEmpty ? "Not added" : "$estimatedRange km",
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade500,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: accentColor,
              size: 27,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 3,
        ),
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: accentColor,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey.shade600,
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: Text(
            "No user logged in",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .snapshots();

    final savedStationsStream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedStations")
        .snapshots();

    final addedStationsStream = FirebaseFirestore.instance
        .collection("charging_stations")
        .where(
          "addedByUid",
          isEqualTo: user.uid,
        )
        .snapshots();

    final chargingSessionsStream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("chargingSessions")
        .snapshots();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: accentColor,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDocStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: accentColor,
              ),
            );
          }

          String name = "";
          String carName = "";
          String vehicleNumber = "";
          String estimatedRange = "";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data =
                snapshot.data!.data() as Map<String, dynamic>?;

            if (data != null) {
              name = data["name"]?.toString() ?? "";
              carName = data["carName"]?.toString() ?? "";
              vehicleNumber =
                  data["vehicleNumber"]?.toString() ?? "";
              estimatedRange =
                  data["estimatedRangeKm"]?.toString() ?? "";
            }
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(
                  name: name,
                  email: user.email ?? "No email available",
                ),

                const SizedBox(height: 18),

                _buildVehicleCard(
                  carName: carName,
                  vehicleNumber: vehicleNumber,
                  estimatedRange: estimatedRange,
                ),

                const SizedBox(height: 22),

                const Text(
                  "Your Activity",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: savedStationsStream,
                      builder: (context, savedSnapshot) {
                        final count =
                            savedSnapshot.data?.docs.length ?? 0;

                        return _buildStatCard(
                          icon: Icons.bookmark,
                          title: "Saved Stations",
                          value: count.toString(),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: addedStationsStream,
                      builder: (context, addedSnapshot) {
                        final count =
                            addedSnapshot.data?.docs.length ?? 0;

                        return _buildStatCard(
                          icon: Icons.ev_station,
                          title: "Stations Added",
                          value: count.toString(),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: chargingSessionsStream,
                      builder: (context, sessionSnapshot) {
                        final count =
                            sessionSnapshot.data?.docs.length ?? 0;

                        return _buildStatCard(
                          icon: Icons.bolt,
                          title: "Charging Sessions",
                          value: count.toString(),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                const Text(
                  "Quick Access",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _buildActionTile(
                  icon: Icons.ev_station,
                  title: "My Added Stations",
                  subtitle: "View stations you added to EVPlug",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyAddedStationsScreen(),
                      ),
                    );
                  },
                ),

                _buildActionTile(
                  icon: Icons.bookmark,
                  title: "Saved Stations",
                  subtitle: "View your saved charging stations",
                  onTap: () {
                    _showSnackBar(
                      "Open Saved Stations from the Home screen.",
                    );
                  },
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(
                        color: Colors.redAccent.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Center(
                  child: Text(
                    "EVPlug",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Center(
                  child: Text(
                    "Smart charging. Smarter journeys.",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
