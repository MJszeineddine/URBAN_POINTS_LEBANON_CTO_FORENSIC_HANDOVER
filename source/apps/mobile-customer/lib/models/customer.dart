import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int pointsBalance;
  final int totalPointsEarned;
  final int totalSpentLbp;
  final String tier;
  final bool isActive;
  final DateTime createdAt;
  final String subscriptionStatus;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.pointsBalance,
    required this.totalPointsEarned,
    required this.totalSpentLbp,
    required this.tier,
    required this.isActive,
    required this.createdAt,
    required this.subscriptionStatus,
  });

  factory Customer.fromFirestore(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      pointsBalance: (data['points_balance'] as num?)?.toInt() ?? 0,
      totalPointsEarned: (data['total_points_earned'] as num?)?.toInt() ?? 0,
      totalSpentLbp: (data['total_spent_lbp'] as num?)?.toInt() ?? 0,
      tier: data['tier'] as String? ?? 'Bronze',
      isActive: data['is_active'] as bool? ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      subscriptionStatus: data['subscription_status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'points_balance': pointsBalance,
      'total_points_earned': totalPointsEarned,
      'total_spent_lbp': totalSpentLbp,
      'tier': tier,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
