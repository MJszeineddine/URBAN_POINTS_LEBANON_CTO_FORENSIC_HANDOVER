import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer.dart';
import 'offer_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Favorites')),
        body: const Center(child: Text('Please sign in to view favorites')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('customers')
            .doc(uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No favorite offers yet'),
            );
          }

          final favorites = snapshot.data!.docs;

          return FutureBuilder<List<Offer>>(
            future: _loadOffers(favorites),
            builder: (context, offerSnapshot) {
              if (offerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (offerSnapshot.hasError) {
                return Center(child: Text('Error: ${offerSnapshot.error}'));
              }

              if (!offerSnapshot.hasData || offerSnapshot.data!.isEmpty) {
                return const Center(child: Text('No offers found'));
              }

              final offers = offerSnapshot.data!;

              return ListView.builder(
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(offer.title),
                      subtitle: Text(offer.description),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _removeFavorite(uid, offer.id),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                OfferDetailScreen(offer: offer),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Offer>> _loadOffers(
    List<QueryDocumentSnapshot> favorites,
  ) async {
    final offers = <Offer>[];

    for (final fav in favorites) {
      try {
        final offerId = fav['offer_id'] as String?;
        if (offerId == null) continue;

        final offerDoc = await _firestore
            .collection('offers')
            .doc(offerId)
            .get();

        if (offerDoc.exists) {
          offers.add(Offer.fromFirestore(offerDoc.data()!, offerDoc.id));
        }
      } catch (e) {
        debugPrint('Error loading offer: $e');
      }
    }

    return offers;
  }

  Future<void> _removeFavorite(String uid, String offerId) async {
    try {
      await _firestore
          .collection('customers')
          .doc(uid)
          .collection('favorites')
          .doc(offerId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
