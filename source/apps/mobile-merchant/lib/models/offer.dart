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
  final String status;
  final double? originalPrice;
  final double? discountedPrice;
  final String? category;
  final String? terms;
  final int redemptionCount;

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
    required this.status,
    this.originalPrice,
    this.discountedPrice,
    this.category,
    this.terms,
    this.redemptionCount = 0,
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
      status: data['status'] as String? ?? 'pending',
      originalPrice: (data['original_price'] as num?)?.toDouble(),
      discountedPrice: (data['discounted_price'] as num?)?.toDouble(),
      category: data['category'] as String?,
      terms: data['terms'] as String?,
      redemptionCount: (data['redemption_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory Offer.fromMap(Map<String, dynamic> data) {
    DateTime created;
    final createdRaw = data['created_at'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    } else if (createdRaw is String) {
      try {
        created = DateTime.parse(createdRaw);
      } catch (_) {
        created = DateTime.now();
      }
    } else {
      created = DateTime.now();
    }

    return Offer(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      // Prefer points_required; fallback to points_cost if present
      pointsRequired: (data['points_required'] as num?)?.toInt() ?? (data['points_cost'] as num?)?.toInt() ?? 0,
      imageUrl: data['image_url'] as String? ?? '',
      validUntil: data['valid_until'] as String? ?? '',
      isActive: data['is_active'] as bool? ?? true,
      discountPercentage: (data['discount_percentage'] as num?)?.toInt(),
      createdAt: created,
      merchantId: data['merchant_id'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      originalPrice: (data['original_price'] as num?)?.toDouble(),
      discountedPrice: (data['discounted_price'] as num?)?.toDouble(),
      category: data['category'] as String?,
      terms: data['terms'] as String?,
      redemptionCount: (data['redemption_count'] as num?)?.toInt() ?? 0,
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

  int get pointsCost => pointsRequired;
}
