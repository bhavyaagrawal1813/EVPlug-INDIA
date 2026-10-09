import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AI is deferred for production; initialize() only logs its state and
  // never makes a network request.
  GeminiService.initialize();

  // The 6-hour EVPlug reminder is scheduled at startup so it keeps
  // firing while the app is closed. Safe on every start: existing
  // alarms are replaced, never duplicated.
  NotificationService.instance.scheduleSixHourReminders();

  runApp(const EVPlugApp());
}

class EVPlugApp extends StatelessWidget {
const EVPlugApp({super.key});

@override
Widget build(BuildContext context) {
return const MaterialApp(
debugShowCheckedModeBanner: false,
home: SplashScreen(),
);
}
}
