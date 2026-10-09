import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_screen.dart';
import 'vehicle_router.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;
  bool _autoVerified = false;
  int? _resendToken;

  Future<void> sendOTP() async {
    String phone = phoneController.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit number")),
      );
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _autoVerified = false;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: "+91$phone",
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _autoVerified = true;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const VehicleCheckRouter()),
                (route) => false,
              );
            }
          } catch (e) {
            // Auto-verification failed, the user will need to enter
            // the OTP manually, so allow codeSent to navigate.
            _autoVerified = false;
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });

          String message = e.message ?? "Verification failed";

          switch (e.code) {
            case 'invalid-phone-number':
              message = "Invalid phone number. Please check and try again.";
              break;
            case 'too-many-requests':
              message = "Too many requests. Please try again later.";
              break;
            default:
              message = e.message ?? "Verification failed. Please try again.";
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _resendToken = resendToken;
          });

          if (_autoVerified) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OTPPage(
                verificationId: verificationId,
                phoneNumber: "+91$phone",
                resendToken: resendToken,
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not send OTP. Please try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030708),

      appBar: AppBar(
        backgroundColor: const Color(0xFF030708),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF52FFC8)),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Phone Login",
              style: TextStyle(
                color: Color(0xFF52FFC8),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // ===== PHONE INPUT WITH +91 FIXED =====
            Row(
              children: [
                // +91 BOX (ALWAYS VISIBLE)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF52FFC8)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "+91",
                    style: TextStyle(
                      color: Color(0xFF52FFC8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // PHONE INPUT
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    enabled: !_isLoading,

                    decoration: InputDecoration(
                      hintText: "Enter phone number",
                      hintStyle: const TextStyle(color: Colors.white54),

                      filled: true,
                      fillColor: Colors.white10,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF52FFC8)),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF52FFC8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF52FFC8),
                  foregroundColor: Colors.black,
                ),
                onPressed: _isLoading ? null : sendOTP,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text("Send OTP", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
