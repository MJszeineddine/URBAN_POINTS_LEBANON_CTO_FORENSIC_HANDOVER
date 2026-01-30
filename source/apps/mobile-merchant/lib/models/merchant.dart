import 'package:cloud_firestore/cloud_firestore.dart';

class Merchant {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String cuisine;
  final double rating;
  final int pointsRate;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime createdAt;

  Merchant({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.cuisine,
    required this.rating,
    required this.pointsRate,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.createdAt,
  });

  factory Merchant.fromFirestore(Map<String, dynamic> data, String id) {
    return Merchant(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      cuisine: data['cuisine'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      pointsRate: (data['points_rate'] as num?)?.toInt() ?? 1,
      imageUrl: data['image_url'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      isActive: data['is_active'] as bool? ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
