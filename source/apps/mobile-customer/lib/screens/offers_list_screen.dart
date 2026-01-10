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
  String _sortBy = 'proximity';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final CustomerService _customerService = CustomerService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  double _balance = 0;

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
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildOffersList()),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _functions
          .httpsCallable('getAvailableOffers')
          .call()
          .then((r) => r.data as Map<String, dynamic>),
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

        if (_searchQuery.isNotEmpty) {
          offers = offers.where((o) => o.title.toLowerCase().contains(_searchQuery)).toList();
        }

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
