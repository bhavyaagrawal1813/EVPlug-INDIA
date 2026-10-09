import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  static Future<void> openMap({
    required double latitude,
    required double longitude,
  }) async {
    final Uri url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  }
}