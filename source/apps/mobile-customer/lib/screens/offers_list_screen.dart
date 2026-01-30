import 'package:flutter/material.dart';
import '../models/offer.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/customer_service.dart';
import 'offer_detail_screen.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  double? _minPoints;
  double? _maxPoints;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final CustomerService _customerService = CustomerService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  double _balance = 0;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _customerService.getBalance();
      if (mounted) {
        setState(() {
          _balance = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search offers...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              )
            : const Text('Discover Offers'),
        actions: [
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('$_balance pts', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g., Food, Entertainment',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value.isEmpty ? null : value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Min Points',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() => _minPoints = double.tryParse(value));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max Points',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() => _maxPoints = double.tryParse(value));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _showFilters = false);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildOffersList()),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    // Determine which backend callable to use based on filters
    late Future<Map<String, dynamic>> offersFuture;

    if (_searchQuery.isNotEmpty) {
      // Use search callable
      offersFuture = _functions
          .httpsCallable('searchOffers')
          .call({
            'query': _searchQuery,
            'limit': 50,
          })
          .then((r) => r.data as Map<String, dynamic>);
    } else if (_selectedCategory != null ||
        _minPoints != null ||
        _maxPoints != null) {
      // Use filter callable
      offersFuture = _functions
          .httpsCallable('getFilteredOffers')
          .call({
            'category': _selectedCategory,
            'minPoints': _minPoints,
            'maxPoints': _maxPoints,
            'limit': 50,
          })
          .then((r) => r.data as Map<String, dynamic>);
    } else {
      // Use default callable for all offers
      offersFuture = _functions
          .httpsCallable('getAvailableOffers')
          .call()
          .then((r) => r.data as Map<String, dynamic>);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: offersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading offers: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final offersList = (data['offers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        var offers = offersList.map((o) => Offer.fromMap(o)).toList();

        if (offers.isEmpty) {
          return const Center(child: Text('No offers found'));
        }

        return ListView.builder(
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(offer.title),
                subtitle: Text(offer.merchantName),
                trailing: offer.used == true
                    ? const Chip(label: Text('Used'))
                    : Text('${offer.pointsCost} pts'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfferDetailScreen(offer: offer),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
