import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/billing_state.dart';
import '../../services/stripe_client.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final BillingRepository _billingRepository = BillingRepository();
  final StripeClient _stripeClient = StripeClient();
  final TextEditingController _priceController =
      TextEditingController(text: '');

  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout(BillingState state) async {
    final priceId = _priceController.text.trim().isEmpty
        ? (state.priceId ?? '')
        : _priceController.text.trim();

    if (priceId.isEmpty) {
      setState(() => _error = 'Please enter a valid price ID.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final uri = await _stripeClient.createCheckoutSession(
        priceId: priceId,
      );
      await _stripeClient.openExternal(uri);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openBillingPortal() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final uri = await _stripeClient.createBillingPortalSession();
      await _stripeClient.openExternal(uri);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _refreshOnce() async {
    try {
      await _billingRepository.fetchLatest();
    } catch (_) {
      // No-op; stream will still emit latest known state
    }
    if (mounted) setState(() {});
  }

  String _statusLabel(BillingState state) {
    switch (state.status) {
      case BillingStatus.active:
        return 'Active';
      case BillingStatus.pastDue:
        return 'Past Due';
      case BillingStatus.canceled:
        return 'Canceled';
      case BillingStatus.free:
        return 'Free';
      case BillingStatus.unknown:
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription & Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _refreshOnce,
          ),
        ],
      ),
      body: StreamBuilder<BillingState>(
        stream: _billingRepository.watchBillingState(),
        builder: (context, snapshot) {
          final state = snapshot.data ?? BillingState.free;
          if (_priceController.text.isEmpty && (state.priceId ?? '').isNotEmpty) {
            _priceController.text = state.priceId!;
          }
          final statusText = _statusLabel(state);
          final subtitle = state.currentPeriodEnd != null
              ? 'Renews ${DateFormat('MMM d, yyyy').format(state.currentPeriodEnd!)}'
              : 'No renewal scheduled';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (state.cancelAtPeriodEnd)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Will cancel at period end.',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price ID',
                    hintText: 'price_...',
                    helperText: 'Leave blank to use your default plan if available.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing || state.isActive
                            ? null
                            : () => _startCheckout(state),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Subscribe'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing || (!state.isActive && !state.hasCustomer)
                            ? null
                            : _openBillingPortal,
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Manage Billing'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isProcessing ? null : _refreshOnce,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
