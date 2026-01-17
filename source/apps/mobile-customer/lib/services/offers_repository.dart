import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;
import '../models/offer.dart';
import '../models/location.dart';

class OffersRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetch offers by location (proximity sorted) or national catalog if no location
  /// Returns offers sorted by distance if location provided, otherwise all offers
  Future<List<Offer>> getOffersByLocation({
    UserLocation? userLocation,
  }) async {
    try {
      // Call backend Cloud Function getOffersByLocationFunc
      final callable = _functions.httpsCallable('getOffersByLocationFunc');
      
      final params = {
        if (userLocation != null) ...{
          'latitude': userLocation.latitude,
          'longitude': userLocation.longitude,
          'radius_km': 50.0, // Default radius
        }
      };

      final response = await callable.call(params);
      
      if (response.data['success'] != true) {
        throw Exception('Backend error: ${response.data['error']}');
      }

      final List<dynamic> offersData = response.data['offers'] ?? [];
      
      return offersData
          .map((o) => Offer.fromMap(o as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error fetching offers by location: $e', name: 'OffersRepository');
      // Fallback to national catalog from Firestore
      return _getNationalCatalog();
    }
  }

  /// Fallback: fetch all offers from Firestore (national catalog)
  Future<List<Offer>> _getNationalCatalog() async {
    try {
      final snapshot = await _firestore
          .collection('offers')
          .where('is_active', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Offer.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      developer.log('Error fetching national catalog: $e', name: 'OffersRepository');
      return [];
    }
  }

  /// Get single offer by ID
  Future<Offer?> getOfferById(String offerId) async {
    try {
      final doc = await _firestore.collection('offers').doc(offerId).get();
      if (doc.exists) {
        return Offer.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      developer.log('Error fetching offer: $e', name: 'OffersRepository');
      return null;
    }
  }

  /// Get customer's redemption history
  Future<List<Map<String, dynamic>>> getRedemptionHistory(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('redemptions')
          .where('user_id', isEqualTo: customerId)
          .orderBy('redeemed_at', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      developer.log('Error fetching redemption history: $e', name: 'OffersRepository');
      return [];
    }
  }

  /// Check if customer has active subscription
  Future<bool> hasActiveSubscription(String customerId) async {
    try {
      final doc = await _firestore.collection('customers').doc(customerId).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['subscription_status'] == 'active';
    } catch (e) {
      developer.log('Error checking subscription: $e', name: 'OffersRepository');
      return false;
    }
  }
}
