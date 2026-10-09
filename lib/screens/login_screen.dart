import 'package:flutter/material.dart';

import 'phone_login_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030708),

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // EVPLUG ICON
                const Icon(
                  Icons.ev_station,
                  color: Color(0xFF00FFAA),
                  size: 95,
                ),

                const SizedBox(height: 20),

                // EVPLUG TITLE
                const Text(
                  "EVPLUG",
                  style: TextStyle(
                    color: Color(0xFF00FFAA),
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 10),

                // TAGLINE
                const Text(
                  "Powering The Future",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 50),

                // PHONE LOGIN BUTTON
                SizedBox(
                  width: 300,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PhoneLoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFAA),
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: const Color(0xFF00FFAA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Continue with Phone",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // SUPPORTING TEXT
                const Text(
                  "Secure login using your mobile number",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}