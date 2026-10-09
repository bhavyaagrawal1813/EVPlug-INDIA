import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/ev_route_service.dart';
import '../services/location_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddStationScreen extends StatefulWidget {
const AddStationScreen({super.key});

@override



State<AddStationScreen> createState() => _AddStationScreenState();
}

class _AddStationScreenState extends State<AddStationScreen> {
final _formKey = GlobalKey<FormState>();

final TextEditingController stationNameController =
TextEditingController();
final TextEditingController locationController =
TextEditingController();
final TextEditingController powerController =
TextEditingController();
final TextEditingController priceController =
TextEditingController();

bool isLoading = false;
double? latitude;
double? longitude;
File? selectedImage;
final ImagePicker imagePicker = ImagePicker();
@override
void dispose() {
stationNameController.dispose();
locationController.dispose();
powerController.dispose();
priceController.dispose();
super.dispose();
}

Future<void> getCurrentLocation() async {
setState(() {
isLoading = true;
});


try {
final Position position = await LocationService.getCurrentPosition();

final String readableAddress = await EVRouteService.reverseGeocode(
position.latitude,
position.longitude,
);

if (!mounted) return;

setState(() {
latitude = position.latitude;
longitude = position.longitude;
locationController.text = readableAddress;
isLoading = false;
});

showSnackBar("Location fetched successfully");
} on LocationFailure catch (failure) {
if (!mounted) return;

setState(() {
isLoading = false;
});

showSnackBar(failure.message);
} catch (e) {
if (!mounted) return;

setState(() {
isLoading = false;
});

showSnackBar("Failed to fetch location");
}

}Future<void> pickImage() async {
  // Camera only. This is a safety-related upload, so picking an existing
  // photo from the gallery is intentionally not offered.
  try {
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image == null) return;

    if (!mounted) return;

    setState(() {
      selectedImage = File(image.path);
    });
  } catch (e) {
    if (!mounted) return;

    // Covers a denied camera permission or an unavailable camera app.
    showSnackBar(
      "Camera is unavailable. Please allow camera access in Settings "
      "and try again.",
    );
  }
}
Future<void> saveStation() async {
  if (!_formKey.currentState!.validate()) return;

  if (latitude == null || longitude == null) {
    showSnackBar("Please use current location first");
    return;
  }

  setState(() {
    isLoading = true;
  });

 final currentUser = FirebaseAuth.instance.currentUser;

try {

  String photoUrl = "";

  if (selectedImage != null) {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("station_photos")
        .child("${DateTime.now().millisecondsSinceEpoch}.jpg");

    await storageRef.putFile(selectedImage!);

    photoUrl = await storageRef.getDownloadURL();
  }

  await FirebaseFirestore.instance
      .collection("charging_stations")
      .add({
  "stationName": stationNameController.text.trim(),
  "location": locationController.text.trim(),
  "powerOutput": powerController.text.trim(),
  "price": priceController.text.trim(),

  "latitude": latitude,
  "longitude": longitude,

  "addedByUid": currentUser?.uid ?? "",

  "createdAt": FieldValue.serverTimestamp(),

  "isActive": true,
  "source": "user",
  "photoUrl": photoUrl,

  // ---------- AI Verification ----------
  "verificationStatus": "Pending",
  "aiConfidence": 0,
  "aiReason": "",
  "reportCount": 0,
  "reviewCount": 0,
  "averageRating": 0.0,
  "lastAiCheck": null,
});

if (currentUser != null) {
  await FirebaseFirestore.instance
      .collection("users")
      .doc(currentUser.uid)
      .set({
    "stationsAdded": FieldValue.increment(1),
  }, SetOptions(merge: true));
}

    stationNameController.clear();
    locationController.clear();
    powerController.clear();
    priceController.clear();
    selectedImage = null;

    if (!mounted) return;

    setState(() {
      latitude = null;
      longitude = null;
      isLoading = false;
    });

    showSnackBar("Station saved successfully");
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    showSnackBar("Failed to save station");
  }
}

void showSnackBar(String message) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
backgroundColor: const Color(0xFF111827),
content: Text(message),
),
);
}

InputDecoration customInput(String hint) {
return InputDecoration(
hintText: hint,
hintStyle: const TextStyle(color: Colors.white54),
filled: true,
fillColor: const Color(0xFF111827),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: BorderSide.none,
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF030712),
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Form(
key: _formKey,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: const Color(0xFF00FFAA),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.ev_station,
color: Colors.black,
size: 28,
),
),
const SizedBox(width: 10),
const Text(
"EVPlug",
style: TextStyle(
color: Colors.white,
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
],
),
const SizedBox(height: 35),
const Text(
"Add Charging Station",
style: TextStyle(
color: Colors.white,
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
const Text(
"Help EV drivers discover a charging station.",
style: TextStyle(
color: Colors.white60,
fontSize: 14,
),
),
const SizedBox(height: 30),
TextFormField(
controller: stationNameController,
style: const TextStyle(color: Colors.white),
decoration: customInput("Station Name"),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return "Enter station name";
}
return null;
},
),
const SizedBox(height: 20),
TextFormField(
controller: locationController,
readOnly: true,
style: const TextStyle(color: Colors.white),
decoration: customInput("Location"),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return "Use current location";
}
return null;
},
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: OutlinedButton.icon(
style: OutlinedButton.styleFrom(
foregroundColor: const Color(0xFF00FFAA),
side: const BorderSide(
color: Color(0xFF00FFAA),
),
padding: const EdgeInsets.symmetric(vertical: 14),
),
onPressed: isLoading ? null : getCurrentLocation,
icon: const Icon(Icons.my_location),
label: Text(
isLoading
? "Fetching location..."
: "Use Current Location",
),
),
),
            const SizedBox(height: 20),
            TextFormField(
              controller: powerController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: customInput("Power Output (kW)"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter power output";
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return "Enter a valid number";
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: customInput("Price per kWh (₹)"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter price";
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed < 0) {
                  return "Enter a valid number";
                }
                return null;
              },
            ),
const SizedBox(height: 20),
InkWell(
  onTap: pickImage,
borderRadius: BorderRadius.circular(14),
child: Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(vertical: 24),
decoration: BoxDecoration(
color: const Color(0xFF111827),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: const Color(0xFF374151),
),
),
          child: selectedImage == null
              ? const Column(
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: Color(0xFF00FFAA),
                      size: 34,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Take Station Photo",
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Optional",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                )
    : ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          selectedImage!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      ),
),
),
const SizedBox(height: 35),
SizedBox(
width: double.infinity,
child: ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF00FFAA),
foregroundColor: Colors.black,
padding: const EdgeInsets.symmetric(vertical: 16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
onPressed: isLoading ? null : saveStation,
child: Text(
isLoading ? "Saving..." : "Add Station",
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
child: OutlinedButton.icon(
style: OutlinedButton.styleFrom(
foregroundColor: Colors.white,
side: const BorderSide(
color: Color(0xFF374151),
),
padding: const EdgeInsets.symmetric(vertical: 15),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
onPressed: () {
Navigator.pop(context);
},
icon: const Icon(Icons.bookmark_outline),
label: const Text(
"Saved Stations",
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
const SizedBox(height: 20),
],
),
),
),
),
);
}
}
