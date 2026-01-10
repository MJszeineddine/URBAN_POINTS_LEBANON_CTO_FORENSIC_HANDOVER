import 'package:flutter/material.dart';

class MerchantOffersEmptyState extends StatelessWidget {
  final VoidCallback onCreatePressed;

  const MerchantOffersEmptyState({
    super.key,
    required this.onCreatePressed,
  });

  static const String emptyTitle = 'No Offers Yet';
  static const String emptyMessage = 'Create your first offer to attract customers';
  static const String actionLabel = 'Create First Offer';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            emptyTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptyMessage,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreatePressed,
            icon: const Icon(Icons.add),
            label: const Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
