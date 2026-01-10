import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MerchantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create new offer (requires active subscription)
  Future<Map<String, dynamic>> createOffer({
    required String title,
    required String description,
    required String category,
    required double pointsValue,
    required int stock,
    required String discountType,
    required double discountAmount,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await _functions.httpsCallable('createOffer').call({
        'title': title,
        'description': description,
        'category': category,
        'points_value': pointsValue,
        'stock': stock,
        'discount_type': discountType,
        'discount_amount': discountAmount,
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating offer: $e');
      rethrow;
    }
  }

  /// Fetch merchant's active offers
  Future<List<Map<String, dynamic>>> fetchMyOffers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('offers')
          .where('merchant_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching my offers: $e');
      rethrow;
    }
  }

  /// Validate QR token and complete redemption
  Future<Map<String, dynamic>> validateRedemption({
    required String qrToken,
    required String qrPin,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await _functions.httpsCallable('validateRedemption').call({
        'qr_token': qrToken,
        'qr_pin': qrPin,
      });

      return result.data as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('Error validating redemption: $e');
      rethrow;
    }
  }

  /// Fetch merchant redemption analytics
  Future<Map<String, dynamic>> fetchAnalytics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final offersSnapshot = await _firestore
          .collection('offers')
          .where('merchant_id', isEqualTo: user.uid)
          .get();

      int totalRedemptions = 0;
      double totalPointsEarned = 0.0;

      for (final offerDoc in offersSnapshot.docs) {
        final redemptionsSnapshot = await offerDoc.reference
            .collection('redemptions')
            .get();
        
        totalRedemptions += redemptionsSnapshot.size;
      }

      return {
        'total_offers': offersSnapshot.size,
        'total_redemptions': totalRedemptions,
        'total_points_earned': totalPointsEarned,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching analytics: $e');
      rethrow;
    }
  }

  /// Check merchant subscription status
  Future<bool> hasActiveSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final subscription = userDoc.data()?['subscription'];
      if (subscription == null) return false;

      final status = subscription['status'];
      final currentPeriodEnd = subscription['current_period_end'];
      
      if (currentPeriodEnd is Timestamp) {
        return status == 'active' &&
            currentPeriodEnd.toDate().isAfter(DateTime.now());
      }
      
      return status == 'active';
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking subscription: $e');
      return false;
    }
  }

  /// Watch merchant redemptions in real-time
  Stream<List<Map<String, dynamic>>> watchRedemptions() {
    try {
      final user = _auth.currentUser;
      if (user == null) return Stream.error('User not authenticated');

      return _firestore
          .collection('redemptions')
          .where('merchant_id', isEqualTo: user.uid)
          .orderBy('redeemed_at', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList())
          .handleError((e) {
            if (kDebugMode) debugPrint('Error watching redemptions: $e');
          });
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting up redemptions watcher: $e');
      return Stream.error(e);
    }
  }
}
