import 'package:flutter_test/flutter_test.dart';
import 'package:urban_points_customer/services/deep_link_service.dart';

void main() {
  group('DeepLinkService', () {
    test('buildUri creates correct URI', () {
      final uri = DeepLinkService.buildUri('offer', params: {'id': '123'});
      expect(uri.scheme, 'uppoints');
      expect(uri.host, 'offer');
      expect(uri.queryParameters['id'], '123');
    });

    test('parseNotificationUri parses deepLink field', () {
      final data = {
        'deepLink': 'uppoints://offer/456',
      };
      final uri = DeepLinkService.parseNotificationUri(data);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'uppoints');
      expect(uri.host, 'offer');
    });

    test('parseNotificationUri falls back to link field', () {
      final data = {
        'link': 'uppoints://points',
      };
      final uri = DeepLinkService.parseNotificationUri(data);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'uppoints');
      expect(uri.host, 'points');
    });

    test('parseNotificationUri returns null for missing link', () {
      final data = {
        'title': 'Some notification',
      };
      final uri = DeepLinkService.parseNotificationUri(data);
      expect(uri, isNull);
    });

    test('parseNotificationUri handles invalid URLs gracefully', () {
      final data = {
        'deepLink': 'not a valid url!!!',
      };
      
      // The service parses this as a Uri, even if not valid scheme
      // What matters is it doesn't crash and returns something
      final uri = DeepLinkService.parseNotificationUri(data);
      // Uri.parse('not a valid url!!!') creates a Uri with path='not a valid url!!!'
      // Just verify it doesn't throw and returns something
      expect(uri != null, true);
    });
  });
}
