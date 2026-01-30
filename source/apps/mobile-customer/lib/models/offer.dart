import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String title;
  final String description;
  final int pointsRequired;
  final String imageUrl;
  final String validUntil;
  final bool isActive;
  final int? discountPercentage;
  final DateTime createdAt;
  final String merchantId;
  final String merchantName;
  final String category;
  final double? distance;
  final bool? used;
  final int pointsCost;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.imageUrl,
    required this.validUntil,
    required this.isActive,
    this.discountPercentage,
    required this.createdAt,
    required this.merchantId,
    required this.merchantName,
    required this.category,
    this.distance,
    this.used = false,
    required this.pointsCost,
  });

  factory Offer.fromFirestore(Map<String, dynamic> data, String id) {
    return Offer(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pointsRequired: (data['points_required'] as num?)?.toInt() ?? 0,
      imageUrl: data['image_url'] as String? ?? '',
      validUntil: data['valid_until'] as String? ?? '',
      isActive: data['is_active'] as bool? ?? true,
      discountPercentage: (data['discount_percentage'] as num?)?.toInt(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      merchantId: data['merchant_id'] as String? ?? '',
      merchantName: data['merchant_name'] as String? ?? 'Merchant',
      category: data['category'] as String? ?? 'General',
      distance: (data['distance_km'] as num?)?.toDouble(),
      used: data['used'] as bool? ?? false,
      pointsCost: (data['points_cost'] as num?)?.toInt() ?? 100,
    );
  }

  factory Offer.fromMap(Map<String, dynamic> data) {
    return Offer(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pointsRequired: (data['points_required'] as num?)?.toInt() ?? 0,
      imageUrl: data['image_url'] as String? ?? '',
      validUntil: data['valid_until'] as String? ?? '',
      isActive: data['is_active'] as bool? ?? true,
      discountPercentage: (data['discount_percentage'] as num?)?.toInt(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      merchantId: data['merchant_id'] as String? ?? '',
      merchantName: data['merchant_name'] as String? ?? 'Merchant',
      category: data['category'] as String? ?? 'General',
      distance: (data['distance_km'] as num?)?.toDouble(),
      used: data['used'] as bool? ?? false,
      pointsCost: (data['points_cost'] as num?)?.toInt() ?? 100,
    );
  }

  DateTime get validUntilDate {
    try {
      return DateTime.parse(validUntil);
    } catch (e) {
      return DateTime.now().add(const Duration(days: 30));
    }
  }

  bool get isValid {
    return isActive && validUntilDate.isAfter(DateTime.now());
  }
}

