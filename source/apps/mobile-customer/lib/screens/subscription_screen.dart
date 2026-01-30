import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// SubscriptionScreen
/// Evidence: Implements subscription plans and entitlements for Qatar parity
/// Users can view available plans, start subscriptions, and check active status
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<List<SubscriptionPlan>> plansFuture;
  late Future<UserSubscription?> currentSubscriptionFuture;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    plansFuture = _fetchPlans();
    currentSubscriptionFuture = _fetchCurrentSubscription();
  }

  Future<List<SubscriptionPlan>> _fetchPlans() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('${_getApiUrl()}/api/subscription-plans'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final plans = (data['data'] as List)
            .map((p) => SubscriptionPlan.fromJson(p))
            .toList();
        return plans;
      }
      throw Exception('Failed to load plans');
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      rethrow;
    }
  }

  Future<UserSubscription?> _fetchCurrentSubscription() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${_getApiUrl()}/api/subscriptions/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return UserSubscription.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      return null;
    }
  }

  Future<void> _startSubscription(String planId) async {
    setState(() => isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${_getApiUrl()}/api/subscriptions/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'planId': planId}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription started successfully!')),
          );
          // Refresh subscription status
          setState(() {
            currentSubscriptionFuture = _fetchCurrentSubscription();
          });
        }
      } else {
        throw Exception('Failed to start subscription');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _cancelSubscription() async {
    setState(() => isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${_getApiUrl()}/api/subscriptions/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription canceled')),
          );
          setState(() {
            currentSubscriptionFuture = _fetchCurrentSubscription();
          });
        }
      } else {
        throw Exception('Failed to cancel subscription');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current subscription status
            FutureBuilder<UserSubscription?>(
              future: currentSubscriptionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasData && snapshot.data != null) {
                  final sub = snapshot.data!;
                  return Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Subscription',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Plan: ${sub.planName}'),
                          Text('Status: ${sub.status}'),
                          Text('Valid until: ${sub.endAt}'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: isLoading ? null : _cancelSubscription,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Cancel Subscription'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            // Available plans section
            const Text(
              'Available Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<SubscriptionPlan>>(
              future: plansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text('Error loading plans');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No plans available');
                }
                final plans = snapshot.data!;
                return Column(
                  children: plans.map((plan) {
                    return PlanCard(
                      plan: plan,
                      isLoading: isLoading,
                      onSelect: () => _startSubscription(plan.id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getApiUrl() {
    // Environment-aware API URL
    const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
    return apiUrl;
  }
}

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isLoading;
  final VoidCallback onSelect;

  const PlanCard({
    required this.plan,
    required this.isLoading,
    required this.onSelect,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description ?? '',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.price}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      plan.period,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text(
                'Subscribe Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final String period;
  final double price;
  final String currency;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.period,
    required this.price,
    required this.currency,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      period: json['period'],
      price: double.parse(json['price'].toString()),
      currency: json['currency'] ?? 'USD',
    );
  }
}

class UserSubscription {
  final String id;
  final String planName;
  final String period;
  final String status;
  final DateTime startAt;
  final DateTime endAt;

  UserSubscription({
    required this.id,
    required this.planName,
    required this.period,
    required this.status,
    required this.startAt,
    required this.endAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      planName: json['plan_name'],
      period: json['period'],
      status: json['status'],
      startAt: DateTime.parse(json['start_at']),
      endAt: DateTime.parse(json['end_at']),
    );
  }
}

