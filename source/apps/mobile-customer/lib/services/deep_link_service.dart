import 'package:flutter/material.dart';

class DeepLinkService {
  /// Parse and handle deep link URIs using the provided BuildContext
  /// Supported formats:
  /// - uppoints://offer/[id]
  /// - uppoints://redemption/[id]
  /// - uppoints://points
  static Future<void> handleUri(Uri uri, BuildContext context) async {
    if (uri.scheme != 'uppoints') {
      return;
    }

    final path = uri.path;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      return;
    }

    final screen = segments[0];

    switch (screen) {
      case 'offer':
        if (segments.length > 1) {
          final offerId = segments[1];
          Navigator.of(context).pushNamed('/offer_detail', arguments: {'offerId': offerId});
        }
        break;

      case 'redemption':
        if (segments.length > 1) {
          final redemptionId = segments[1];
          Navigator.of(context).pushNamed(
            '/redemption_confirmation',
            arguments: {'redemptionId': redemptionId},
          );
        }
        break;

      case 'points':
        Navigator.of(context).pushNamed('/points_history');
        break;

      case 'redemption_history':
        Navigator.of(context).pushNamed('/redemption_history');
        break;

      default:
        // Unknown route, do nothing
        break;
    }
  }

  /// Parse URI from notification data payload
  /// The FCM data should contain a 'deepLink' or 'link' field
  static Uri? parseNotificationUri(Map<String, dynamic> data) {
    final deepLink = data['deepLink'] as String? ?? data['link'] as String?;
    if (deepLink == null) return null;

    try {
      return Uri.parse(deepLink);
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
      return null;
    }
  }

  /// Build a deep link URI for given screen and parameters
  static Uri buildUri(String screen, {Map<String, String>? params}) {
    var url = 'uppoints://$screen';

    if (params != null && params.isNotEmpty) {
      final queryParams = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      url = '$url?$queryParams';
    }

    return Uri.parse(url);
  }
}
