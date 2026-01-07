import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum BillingStatus { free, active, pastDue, canceled, unknown }

class BillingState {
  const BillingState({
    required this.status,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.priceId,
    this.stripeCustomerId,
  });

  final BillingStatus status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String? priceId;
  final String? stripeCustomerId;

  bool get isActive => status == BillingStatus.active;
  bool get hasCustomer => (stripeCustomerId ?? '').isNotEmpty;

  static BillingStatus _parseStatus(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'active':
        return BillingStatus.active;
      case 'past_due':
      case 'pastdue':
        return BillingStatus.pastDue;
      case 'canceled':
      case 'cancelled':
        return BillingStatus.canceled;
      case 'free':
        return BillingStatus.free;
      default:
        return BillingStatus.unknown;
    }
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed;
    }
    return null;
  }

  factory BillingState.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const BillingState(status: BillingStatus.free);
    }
    return BillingState(
      status: _parseStatus(data['subscriptionStatus'] as String?),
      currentPeriodEnd: _parseTimestamp(data['currentPeriodEnd']),
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] == true,
      priceId: data['priceId'] as String?,
      stripeCustomerId: data['stripeCustomerId'] as String?,
    );
  }

  static const BillingState free = BillingState(status: BillingStatus.free);
}

class BillingRepository {
  BillingRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<BillingState> watchBillingState() async* {
    yield BillingState.free;
    await for (final user in _auth.userChanges()) {
      if (user == null) {
        yield BillingState.free;
        continue;
      }

      yield* _firestore
          .collection('users')
          .doc(user.uid)
          .collection('billing')
          .doc('subscription')
          .snapshots()
          .map((snapshot) => BillingState.fromMap(snapshot.data()))
          .handleError((_) => BillingState.free);
    }
  }

  Future<BillingState> fetchLatest() async {
    final user = _auth.currentUser;
    if (user == null) return BillingState.free;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('billing')
          .doc('subscription')
          .get();
      return BillingState.fromMap(doc.data());
    } catch (_) {
      return BillingState.free;
    }
  }
}
