
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportReviewScreen extends StatefulWidget {
  const SupportReviewScreen({super.key});

  @override
  State<SupportReviewScreen> createState() => _SupportReviewScreenState();
}

class _SupportReviewScreenState extends State<SupportReviewScreen> {
  int _selectedRating = 5;
  bool _isOpeningReview = false;

  // ============================================================
  // LEGAL URLS
  // ============================================================

  static const String _privacyPolicyUrl =
      'https://sites.google.com/view/evplug-privacy-policy/home';

  static const String _termsConditionsUrl =
      'https://sites.google.com/view/evplugtermsandcondition/home';

  static const String _accountDeletionUrl =
      'https://sites.google.com/view/evplug/home';

  // ============================================================

  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.app.evplug',
  );

  Future<void> _openPlayStoreReview() async {
    setState(() {
      _isOpeningReview = true;
    });

    try {
      final marketUri = Uri.parse(
        'market://details?id=com.app.evplug',
      );

      bool opened = false;

      try {
        opened = await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }

      if (!opened) {
        opened = await launchUrl(
          _playStoreUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Play Store. Please try again later.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Play Store. Please try again later.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningReview = false;
        });
      }
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'evplugapp2026@gmail.com',
      queryParameters: {
        'subject': 'EVPlug Support Request',
      },
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No email application is available. '
              'Contact: evplugapp2026@gmail.com',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text(
      'No email application is available. '
      'Contact: evplugapp2026@gmail.com',
    ),
    duration: Duration(seconds: 5),
  ),
);
      }
    }
  }

  Future<void> _openLegalPage(
    String url,
    String pageName,
  ) async {
    if (url.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$pageName URL has not been added yet.',
            ),
          ),
        );
      }
      return;
    }

    final uri = Uri.tryParse(url.trim());

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid $pageName URL.',
            ),
          ),
        );
      }
      return;
    }

    try {
      // Directly launch the HTTPS URL externally.
      // We intentionally do not use canLaunchUrl() here because
      // it can return false on Android even when a browser is
      // available to open the URL.
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open $pageName. Please try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open $pageName. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildLegalButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Icon(
          icon,
          color: const Color(0xFF00FFAA),
          size: 26,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.open_in_new,
          color: Colors.white54,
          size: 20,
        ),
        onTap: () => _openLegalPage(url, title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030712),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'EVPlug Support',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.ev_station,
                color: Color(0xFF00FFAA),
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'How was your experience?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Your review helps us improve EVPlug and helps '
                'other EV users discover the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: _isOpeningReview
                      ? null
                      : () {
                          setState(() {
                            _selectedRating = index + 1;
                          });
                        },
                  icon: Icon(
                    index < _selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                '$_selectedRating out of 5 stars',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        color: Color(0xFF00FFAA),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Leave a review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tap the button below to open EVPlug on Google Play. '
                    'You can give your rating and write your review directly '
                    'on the Play Store.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed:
                    _isOpeningReview ? null : _openPlayStoreReview,
                icon: _isOpeningReview
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(
                        Icons.star_rate_rounded,
                        size: 24,
                      ),
                label: Text(
                  _isOpeningReview
                      ? 'Opening Google Play...'
                      : 'Rate EVPlug on Google Play',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFAA),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      const Color(0xFF00FFAA).withOpacity(0.6),
                  disabledForegroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _contactSupport,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Contact Support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FFAA),
                  side: const BorderSide(
                    color: Color(0xFF00FFAA),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Legal & Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildLegalButton(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How EVPlug collects and uses your data',
              url: _privacyPolicyUrl,
            ),

            _buildLegalButton(
              icon: Icons.gavel_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Terms for using EVPlug',
              url: _termsConditionsUrl,
            ),

            _buildLegalButton(
              icon: Icons.delete_outline,
              title: 'Account & Data Deletion',
              subtitle: 'Request deletion of your EVPlug account',
              url: _accountDeletionUrl,
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVPlug Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use this page to rate and review EVPlug on Google Play '
                    'or contact our support team for help, bug reports, '
                    'or other issues.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

