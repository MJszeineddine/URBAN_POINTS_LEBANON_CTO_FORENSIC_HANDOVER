import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer.dart';

class EditOfferScreen extends StatefulWidget {
  final Offer offer;

  const EditOfferScreen({super.key, required this.offer});

  @override
  State<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _termsController;
  late TextEditingController _pointsCostController;
  late TextEditingController _originalPriceController;
  late TextEditingController _discountedPriceController;
  
  late String _selectedCategory;
  bool _isSubmitting = false;
  
  final List<Map<String, String>> _categories = [
    {'value': 'food_drink', 'label': 'Food & Drink', 'icon': '🍔'},
    {'value': 'shopping', 'label': 'Shopping', 'icon': '🛍️'},
    {'value': 'entertainment', 'label': 'Entertainment', 'icon': '🎬'},
    {'value': 'health_beauty', 'label': 'Health & Beauty', 'icon': '💆'},
    {'value': 'travel', 'label': 'Travel', 'icon': '✈️'},
    {'value': 'services', 'label': 'Services', 'icon': '🔧'},
    {'value': 'other', 'label': 'Other', 'icon': '📦'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.offer.title);
    _descriptionController = TextEditingController(text: widget.offer.description);
    _termsController = TextEditingController(text: widget.offer.terms ?? '');
    _pointsCostController = TextEditingController(text: widget.offer.pointsCost.toString());
    _originalPriceController = TextEditingController(text: widget.offer.originalPrice?.toString() ?? '');
    _discountedPriceController = TextEditingController(text: widget.offer.discountedPrice?.toString() ?? '');
    _selectedCategory = widget.offer.category ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _pointsCostController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    super.dispose();
  }

  bool _canEdit() {
    // Can only edit if status is pending or rejected, or if approved but need to resubmit
    return widget.offer.status == 'pending' || widget.offer.status == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Offer'),
        actions: [
          if (widget.offer.status == 'approved')
            IconButton(
              icon: Icon(widget.offer.isActive ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleActiveStatus,
              tooltip: widget.offer.isActive ? 'Deactivate' : 'Activate',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Banner
            _buildStatusBanner(),
            const SizedBox(height: 16),
            
            if (!canEdit) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This offer is ${widget.offer.status}. You can only activate/deactivate it, not edit details.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            _buildSectionHeader('Offer Details'),
            const SizedBox(height: 16),
            
            // Title
            TextFormField(
              controller: _titleController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Offer Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an offer title';
                }
                if (value.trim().length < 5) {
                  return 'Title must be at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                if (value.trim().length < 20) {
                  return 'Description must be at least 20 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat['value'],
                  enabled: canEdit,
                  child: Row(
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(cat['label']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: canEdit ? (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              } : null,
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Pricing'),
            const SizedBox(height: 16),
            
            // Points Cost
            TextFormField(
              controller: _pointsCostController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Points Required *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.stars),
                suffixText: 'points',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter points cost';
                }
                final points = int.tryParse(value);
                if (points == null || points <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Original Price
            TextFormField(
              controller: _originalPriceController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Original Price',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'LBP',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            
            // Discounted Price
            TextFormField(
              controller: _discountedPriceController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Discounted Price',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer),
                suffixText: 'LBP',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Terms & Conditions'),
            const SizedBox(height: 16),
            
            // Terms
            TextFormField(
              controller: _termsController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Terms & Conditions *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.gavel),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter terms and conditions';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Stats Section
            _buildSectionHeader('Performance'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Redemptions', widget.offer.redemptionCount.toString(), Icons.redeem),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Status', widget.offer.status.toUpperCase(), Icons.info),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            if (canEdit) ...[
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _updateOffer,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSubmitting ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.offer.status == 'rejected' 
                    ? 'Changes will be resubmitted for approval'
                    : 'Changes will require re-approval',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    String message;
    IconData icon;

    if (widget.offer.status == 'approved' && widget.offer.isActive) {
      color = Colors.green;
      message = 'This offer is ACTIVE and visible to customers';
      icon = Icons.check_circle;
    } else if (widget.offer.status == 'approved' && !widget.offer.isActive) {
      color = Colors.grey;
      message = 'This offer is approved but currently INACTIVE';
      icon = Icons.pause_circle;
    } else if (widget.offer.status == 'pending') {
      color = Colors.orange;
      message = 'This offer is awaiting admin approval';
      icon = Icons.schedule;
    } else {
      color = Colors.red;
      message = 'This offer was rejected. Edit and resubmit.';
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActiveStatus() async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offer.id)
          .update({
        'is_active': !widget.offer.isActive,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.offer.isActive ? 'Offer deactivated' : 'Offer activated'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating offer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'points_cost': int.parse(_pointsCostController.text),
        'original_price': _originalPriceController.text.isNotEmpty ? double.parse(_originalPriceController.text) : null,
        'discounted_price': _discountedPriceController.text.isNotEmpty ? double.parse(_discountedPriceController.text) : null,
        'terms': _termsController.text.trim(),
        'status': 'pending', // Reset to pending for re-approval
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offer.id)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer updated and resubmitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating offer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
