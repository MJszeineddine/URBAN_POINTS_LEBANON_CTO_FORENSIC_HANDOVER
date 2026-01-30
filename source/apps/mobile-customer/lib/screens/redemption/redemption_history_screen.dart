import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'redemption_confirmation_screen.dart';

class RedemptionHistoryScreen extends StatefulWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  State<RedemptionHistoryScreen> createState() =>
      _RedemptionHistoryScreenState();
}

class _RedemptionHistoryScreenState extends State<RedemptionHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // all, completed, pending, failed

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Redemption History')),
        body: const Center(child: Text('Please sign in to view redemptions')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Redemption History')),
      body: Column(
        children: [
          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Failed', 'failed'),
              ],
            ),
          ),
          // Redemption list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getRedemptionsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No redemptions found'),
                  );
                }

                final redemptions = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: redemptions.length,
                  itemBuilder: (context, index) {
                    final doc = redemptions[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildRedemptionCard(
                      context,
                      doc.id,
                      data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
    );
  }

  Stream<QuerySnapshot> _getRedemptionsStream(String uid) {
    Query query = _firestore
        .collection('redemptions')
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true);

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  Widget _buildRedemptionCard(
    BuildContext context,
    String redemptionId,
    Map<String, dynamic> data,
  ) {
    final status = data['status'] as String? ?? 'unknown';
    final offerTitle = data['offer_title'] as String? ?? 'Unknown Offer';
    final merchantName = data['merchant_name'] as String? ?? 'Unknown Merchant';
    final pointsEarned = data['points_earned'] as int? ?? 0;
    final createdAt = data['created_at'] as Timestamp?;

    final isCompleted = status == 'completed' || status == 'success';
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    final statusIcon = isCompleted ? Icons.check_circle : Icons.hourglass_top;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(offerTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Merchant: $merchantName'),
            Text(
              'Status: ${status.toUpperCase()}',
              style: TextStyle(color: statusColor),
            ),
            if (createdAt != null)
              Text(
                'Date: ${_formatDateTime(createdAt.toDate())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('+$pointsEarned pts',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  RedemptionConfirmationScreen(redemptionId: redemptionId),
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
