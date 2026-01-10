import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CustomerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch all active offers available to customer
  Future<List<Map<String, dynamic>>> fetchOffers() async {
    try {
      final snapshot = await _firestore
          .collection('offers')
          .where('status', isEqualTo: 'approved')
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching offers: $e');
      rethrow;
    }
  }

  /// Get customer balance
  Future<double> getBalance() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await _functions.httpsCallable('getBalance').call();
      return (result.data['balance'] as num).toDouble();
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting balance: $e');
      rethrow;
    }
  }

  /// Generate QR token for redemption (60s TTL)
  Future<String> generateQRToken(String offerId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await _functions.httpsCallable('generateQRToken').call({
        'offer_id': offerId,
      });
      
      return result.data['qr_token'] as String;
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating QR token: $e');
      rethrow;
    }
  }

  /// Fetch customer redemption history
  Future<List<Map<String, dynamic>>> fetchRedemptionHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('redemptions')
          .orderBy('redeemed_at', descending: true)
          .limit(50)
          .get();
      
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching redemption history: $e');
      rethrow;
    }
  }

  /// Redeem offer using QR PIN
  Future<Map<String, dynamic>> redeemOffer({
    required String offerId,
    required String qrPin,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await _functions.httpsCallable('redeemOffer').call({
        'offer_id': offerId,
        'qr_pin': qrPin,
      });
      
      return result.data as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('Error redeeming offer: $e');
      rethrow;
    }
  }

  /// Watch customer balance in real-time
  Stream<double> watchBalance() {
    try {
      final user = _auth.currentUser;
      if (user == null) return Stream.error('User not authenticated');

      return _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0)
          .handleError((e) {
            if (kDebugMode) debugPrint('Error watching balance: $e');
          });
    } catch (e) {
      if (kDebugMode) debugPrint('Error setting up balance watcher: $e');
      return Stream.error(e);
    }
  }

  /// Watch redemptions in real-time
  Stream<List<Map<String, dynamic>>> watchRedemptions() {
    try {
      final user = _auth.currentUser;
      if (user == null) return Stream.error('User not authenticated');

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('redemptions')
          .orderBy('redeemed_at', descending: true)
          .limit(50)
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
