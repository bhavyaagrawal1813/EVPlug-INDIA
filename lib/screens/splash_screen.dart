import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'vehicle_router.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.forward();

    navigateNext();
  }

  Future<void> navigateNext() async {
    // Route as soon as the auth state is known. The animation is purely
    // visual, so there is no reason to hold the user for a fixed delay.
    try {
      await FirebaseAuth.instance.authStateChanges().first;
    } catch (e) {
      // Auth state unavailable, fall through to the login screen.
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
       builder: (_) =>
    FirebaseAuth.instance.currentUser != null
        ? const VehicleCheckRouter()
        : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF030708),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {

            double progress = _controller.value;
            int percent = (progress * 100).toInt();

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Opacity(
                  opacity: 0.6 + (_controller.value * 0.4),
                  child: const Icon(
                    Icons.ev_station,
                    size: 110,
                    color: Color(0xFF52FFC8),
                  ),
                ),

                const SizedBox(height: 10),

                RichText(
                  text: const TextSpan(
                    text: "EV",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF52FFC8),
                      letterSpacing: 3,
                    ),
                    children: [
                      TextSpan(
                        text: "PLUG",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  "POWERING THE FUTURE",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 45),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text(
                      "CHARGING...",
                      style: TextStyle(
                        color: Color(0xFF52FFC8),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      "$percent%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Container(
                  width: 320,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF52FFC8),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),

                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00FFAA),
                                Color(0xFF52FFC8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

