import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stripe client for calling backend checkout/billing endpoints.
class StripeClient {
  StripeClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<Uri> createCheckoutSession({
    required String priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to start a subscription.');
    }

    if (priceId.isEmpty) {
      throw Exception('A priceId is required to start checkout.');
    }

    final callable = _functions.httpsCallable('createCheckoutSession');
    final result = await callable.call({
      'priceId': priceId,
      if (successUrl != null) 'successUrl': successUrl,
      if (cancelUrl != null) 'cancelUrl': cancelUrl,
    });

    final url = _extractUrl(result.data);
    return _validateHttpsUrl(url);
  }

  Future<Uri> createBillingPortalSession({String? returnUrl}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to manage billing.');
    }

    final callable = _functions.httpsCallable('createBillingPortalSession');
    final result = await callable.call({
      if (returnUrl != null) 'returnUrl': returnUrl,
    });

    final url = _extractUrl(result.data);
    return _validateHttpsUrl(url);
  }

  Future<void> openExternal(Uri url) async {
    final success = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!success) {
      throw Exception('Could not open ${url.toString()}');
    }
  }

  Uri _extractUrl(dynamic data) {
    // Expected shapes: {url: "https://..."} or {data: {url: "https://..."}}
    if (data is Map && data['url'] is String) {
      return Uri.parse(data['url'] as String);
    }
    if (data is Map && data['data'] is Map && (data['data'] as Map)['url'] is String) {
      return Uri.parse((data['data'] as Map)['url'] as String);
    }
    throw Exception('Stripe callable did not return a URL.');
  }

  Uri _validateHttpsUrl(Uri url) {
    if (!url.hasScheme || url.scheme != 'https' || url.toString().isEmpty) {
      throw Exception('Invalid checkout/billing URL.');
    }
    return url;
  }
}
