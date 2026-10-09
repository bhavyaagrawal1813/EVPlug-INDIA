import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'vehicle_router.dart';

class OTPPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const OTPPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OTPPage> createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  // A single controller holds the full code. The six boxes are driven from
  // it, which makes pasting, SMS autofill and auto-verification reliable
  // without six separate platform text channels.
  final TextEditingController otpController = TextEditingController();

  final FocusNode otpFocus = FocusNode();

  late String _verificationId;
  int? _resendToken;

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String get otpCode => otpController.text.trim();

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;

    // Request focus as soon as the screen is ready so the keyboard opens
    // immediately and SMS autofill can populate the field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) otpFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    otpController.dispose();
    otpFocus.dispose();
    super.dispose();
  }

  void _onOtpChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits != value) {
      final selection = TextSelection.collapsed(offset: digits.length);
      otpController.value = TextEditingValue(
        text: digits,
        selection: selection,
      );
      return;
    }

    // Verify as soon as the code is complete. This removes a manual tap
    // and one round trip from the login flow.
    if (digits.length == 6 && !_isVerifying) {
      verifyOTP();
    }
  }

  Future<void> verifyOTP() async {
    if (_isVerifying) return;

    if (FirebaseAuth.instance.currentUser != null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const VehicleCheckRouter(),
          ),
          (route) => false,
        );
      }
      return;
    }

    if (otpCode.length != 6) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const VehicleCheckRouter(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-verification-code':
          message = "Invalid OTP. Please check the OTP and try again.";
          break;
        case 'invalid-verification-id':
        case 'session-expired':
          message = "OTP expired. Please request a new OTP.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;
        case 'invalid-phone-number':
          message = "Invalid phone number. Please check and try again.";
          break;
        case 'network-request-failed':
          message = "Network error. Please check your connection.";
          break;
        default:
          message = e.message ?? "Verification failed. Please try again.";
      }

      if (mounted) {
        _clearCode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        _clearCode();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification failed. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _clearCode() {
    otpController.clear();
  }

  Future<void> resendOTP() async {
    if (_isResending || _isVerifying || _resendCooldown > 0) return;

    setState(() {
      _isResending = true;
    });

    _startResendCooldown();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const VehicleCheckRouter(),
                ),
                (route) => false,
              );
            }
          } catch (e) {
            // Auto-verification failed, user will need to enter OTP manually
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isResending = false;
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isResending = false;
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
            _clearCode();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _resendCooldown = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not resend OTP. Please try again."),
          ),
        );
      }
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    _resendCooldown = 30;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
      });
      if (_resendCooldown <= 0) {
        timer.cancel();
      }
    });
  }

  Widget _otpBox(int index, String digits) {
    final isFilled = index < digits.length;
    final digit = isFilled ? digits[index] : '';
    final isFocused = otpFocus.hasFocus && index == digits.length;

    return Container(
      width: 48,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? const Color(0xFF00FFAA) : Colors.white24,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030708),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030708),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter OTP",
              style: TextStyle(
                color: Color(0xFF00FFAA),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Sent to ${widget.phoneNumber}",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 30),
            Stack(
              alignment: Alignment.center,
              children: [
                // Rebuilt whenever the controller changes so each
                // entered digit is visible while typing, pasting
                // or SMS-autofilling the code.
                ListenableBuilder(
                  listenable: otpController,
                  builder: (context, _) {
                    final digits = otpController.text;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) => _otpBox(index, digits)),
                    );
                  },
                ),
                // Real input field, visually hidden, so the platform SMS
                // autofill and paste both work against a single field.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: otpController,
                      focusNode: otpFocus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onOtpChanged,
                      onSubmitted: (_) => verifyOTP(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Verification happens automatically once the 6-digit code is entered.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFAA),
                  foregroundColor: Colors.black,
                ),
                onPressed: (_isVerifying || otpCode.length != 6)
                    ? null
                    : verifyOTP,
                child: _isVerifying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Verify OTP",
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  _resendCooldown > 0 || _isResending || _isVerifying
                  ? null
                  : resendOTP,
              child: Text(
                _resendCooldown > 0
                    ? "Resend OTP in $_resendCooldown s"
                    : "Resend OTP",
                style: TextStyle(
                  color: _resendCooldown > 0
                      ? Colors.white54
                      : const Color(0xFF00FFAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
