import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/offer.dart';
import 'create_offer_screen.dart';
import 'edit_offer_screen.dart';
import '../widgets/empty_states/merchant_offers_empty_state.dart';

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  String _filterStatus = 'all'; // all, active, pending, rejected
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final merchantId = FirebaseAuth.instance.currentUser?.uid;
    
    if (merchantId == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Offers'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Offers')),
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(value: 'pending', child: Text('Pending Approval')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _functions.httpsCallable('getMyOffers').call().then((r) => r.data as Map<String, dynamic>),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final offersList = (data['offers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          var offers = offersList.map((o) => Offer.fromMap(o)).toList();

          // Apply filter
          if (_filterStatus == 'active') {
            offers = offers.where((o) => o.status == 'approved' && o.isActive).toList();
          }

          if (offers.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return _buildOfferCard(offer);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateOfferScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Offer'),
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery(String merchantId) {
    var query = FirebaseFirestore.instance
        .collection('offers')
        .where('merchant_id', isEqualTo: merchantId);

    if (_filterStatus == 'active') {
      query = query.where('is_active', isEqualTo: true).where('status', isEqualTo: 'approved');
    } else if (_filterStatus == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else if (_filterStatus == 'rejected') {
      query = query.where('status', isEqualTo: 'rejected');
    }

    return query.orderBy('created_at', descending: true).snapshots();
  }

  Widget _buildEmptyState() {
    return MerchantOffersEmptyState(
      onCreatePressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateOfferScreen()),
        );
      },
    );
  }

  Widget _buildOfferCard(Offer offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditOfferScreen(offer: offer),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offer.description,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(offer),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.stars,
                    '${offer.pointsCost} Points',
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  if (offer.originalPrice != null && offer.discountedPrice != null)
                    _buildInfoChip(
                      Icons.local_offer,
                      '${((1 - (offer.discountedPrice! / offer.originalPrice!)) * 100).toInt()}% OFF',
                      Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Redeemed: ${offer.redemptionCount}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditOfferScreen(offer: offer),
                            ),
                          );
                        },
                        tooltip: 'Edit Offer',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _confirmDelete(offer),
                        tooltip: 'Delete Offer',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Offer offer) {
    Color color;
    String label;
    IconData icon;

    if (offer.status == 'approved' && offer.isActive) {
      color = Colors.green;
      label = 'ACTIVE';
      icon = Icons.check_circle;
    } else if (offer.status == 'pending') {
      color = Colors.orange;
      label = 'PENDING';
      icon = Icons.schedule;
    } else if (offer.status == 'rejected') {
      color = Colors.red;
      label = 'REJECTED';
      icon = Icons.cancel;
    } else {
      color = Colors.grey;
      label = 'INACTIVE';
      icon = Icons.pause_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Offer offer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offer'),
        content: Text('Are you sure you want to delete "${offer.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteOffer(offer);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOffer(Offer offer) async {
    try {
      await FirebaseFirestore.instance.collection('offers').doc(offer.id).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting offer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
