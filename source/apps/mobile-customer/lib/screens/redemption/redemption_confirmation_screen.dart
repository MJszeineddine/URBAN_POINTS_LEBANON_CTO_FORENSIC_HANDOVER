import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RedemptionConfirmationScreen extends StatefulWidget {
  final String redemptionId;
  final String? status;
  final String? offerId;

  const RedemptionConfirmationScreen({
    super.key,
    required this.redemptionId,
    this.status,
    this.offerId,
  });

  @override
  State<RedemptionConfirmationScreen> createState() =>
      _RedemptionConfirmationScreenState();
}

class _RedemptionConfirmationScreenState
    extends State<RedemptionConfirmationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _redemptionData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRedemptionDetails();
  }

  Future<void> _loadRedemptionDetails() async {
    try {
      final doc = await _firestore
          .collection('redemptions')
          .doc(widget.redemptionId)
          .get();

      if (doc.exists) {
        setState(() {
          _redemptionData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Redemption not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading redemption: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Redemption Confirmation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Redemption Confirmation')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (_redemptionData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Redemption Confirmation')),
        body: const Center(child: Text('No redemption data')),
      );
    }

    final data = _redemptionData!;
    final status = data['status'] as String? ?? 'completed';
    final isSuccess = status == 'completed' || status == 'success';
    final offerTitle = data['offer_title'] as String? ?? 'Offer';
    final merchantName = data['merchant_name'] as String? ?? 'Merchant';
    final pointsEarned = data['points_earned'] as int? ?? 0;
    final createdAt = data['created_at'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(title: const Text('Redemption Confirmation')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success/Failure Icon
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),

                // Status Title
                Text(
                  isSuccess ? 'Redemption Successful!' : 'Redemption Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Offer', offerTitle),
                        const SizedBox(height: 16),
                        _buildDetailRow('Merchant', merchantName),
                        const SizedBox(height: 16),
                        if (isSuccess)
                          _buildDetailRow(
                            'Points Earned',
                            '$pointsEarned',
                            highlight: true,
                          ),
                        if (isSuccess) const SizedBox(height: 16),
                        if (createdAt != null)
                          _buildDetailRow(
                            'Date',
                            _formatDateTime(createdAt.toDate()),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Button
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? Colors.green : null,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
