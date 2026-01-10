import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/merchant_service.dart';

class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termsController = TextEditingController();
  final _pointsCostController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  
  String _selectedCategory = 'food_drink';
  bool _isSubmitting = false;
  final MerchantService _merchantService = MerchantService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  String? _error;
  
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _termsController.dispose();
    _pointsCostController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _functions.httpsCallable('createOffer').call({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'points_cost': int.parse(_pointsCostController.text),
        'original_price': _originalPriceController.text.isNotEmpty
            ? double.parse(_originalPriceController.text)
            : null,
        'discounted_price': _discountedPriceController.text.isNotEmpty
            ? double.parse(_discountedPriceController.text)
            : null,
        'terms': _termsController.text.trim(),
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer created successfully!')),
        );
      } else {
        setState(() => _error = data['error'] as String? ?? 'Failed to create offer');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Offer'),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitOffer,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Offer'),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Offer Details'),
            const SizedBox(height: 16),
            
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Offer Title *',
                hintText: 'e.g., 20% OFF All Main Courses',
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
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe your offer in detail',
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
                  child: Row(
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(cat['label']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Pricing'),
            const SizedBox(height: 16),
            
            // Points Cost
            TextFormField(
              controller: _pointsCostController,
              decoration: const InputDecoration(
                labelText: 'Points Required *',
                hintText: 'e.g., 500',
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
              decoration: const InputDecoration(
                labelText: 'Original Price',
                hintText: 'e.g., 100.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'LBP',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Discounted Price
            TextFormField(
              controller: _discountedPriceController,
              decoration: const InputDecoration(
                labelText: 'Discounted Price',
                hintText: 'e.g., 80.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer),
                suffixText: 'LBP',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final discounted = double.tryParse(value);
                  if (discounted == null || discounted <= 0) {
                    return 'Please enter a valid price';
                  }
                  
                  final original = double.tryParse(_originalPriceController.text);
                  if (original != null && discounted >= original) {
                    return 'Discounted price must be less than original';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Terms & Conditions'),
            const SizedBox(height: 16),
            
            // Terms
            TextFormField(
              controller: _termsController,
              decoration: const InputDecoration(
                labelText: 'Terms & Conditions *',
                hintText: 'e.g., Valid for dine-in only. Cannot be combined with other offers.',
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
            
            // Preview Button
            OutlinedButton.icon(
              onPressed: _previewOffer,
              icon: const Icon(Icons.preview),
              label: const Text('Preview Offer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Submit Button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitOffer,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit for Approval'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Your offer will be reviewed by our team before going live',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

  void _previewOffer() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final category = _categories.firstWhere((cat) => cat['value'] == _selectedCategory);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offer Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _titleController.text,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(category['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(category['label']!, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 16),
              Text(_descriptionController.text),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '${_pointsCostController.text} Points',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_originalPriceController.text.isNotEmpty && _discountedPriceController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${_originalPriceController.text} LBP',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_discountedPriceController.text} LBP',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Terms & Conditions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _termsController.text,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
