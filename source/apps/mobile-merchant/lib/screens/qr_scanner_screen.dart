import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleQRScanned(String displayCode) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Navigate to PIN entry
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PINEntryScreen(displayCode: displayCode),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redemption successful!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              _handleQRScanned(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }
}

class PINEntryScreen extends StatefulWidget {
  final String displayCode;

  const PINEntryScreen({super.key, required this.displayCode});

  @override
  State<PINEntryScreen> createState() => _PINEntryScreenState();
}

class _PINEntryScreenState extends State<PINEntryScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _validatePIN() async {
    if (_pinController.text.isEmpty) {
      setState(() => _error = 'PIN required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call backend validatePIN
      final callable = FirebaseFunctions.instance.httpsCallable('validatePIN');
      final merchantId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      final result = await callable.call({
        'displayCode': widget.displayCode,
        'pin': _pinController.text,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['nonce'] == null) {
        setState(() => _error = data['error'] as String? ?? 'Invalid PIN');
        return;
      }

      // PIN verified - proceed to redemption confirm
      if (mounted) {
        final confirmResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RedemptionConfirmScreen(
              displayCode: widget.displayCode,
              tokenNonce: data['nonce'] as String,
              offerId: data['offer_id'] as String? ?? 'unknown',
              pointsCost: (data['points_cost'] as num?)?.toInt() ?? 0,
            ),
          ),
        );

        if (confirmResult == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                label: const Text('PIN (6 digits)'),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _validatePIN,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify PIN'),
            ),
          ],
        ),
      ),
    );
  }
}

class RedemptionConfirmScreen extends StatefulWidget {
  final String displayCode;
  final String tokenNonce;
  final String offerId;
  final int pointsCost;

  const RedemptionConfirmScreen({
    super.key,
    required this.displayCode,
    required this.tokenNonce,
    required this.offerId,
    required this.pointsCost,
  });

  @override
  State<RedemptionConfirmScreen> createState() => _RedemptionConfirmScreenState();
}

class _RedemptionConfirmScreenState extends State<RedemptionConfirmScreen> {
  bool _isLoading = false;

  Future<void> _confirmRedemption() async {
    setState(() => _isLoading = true);

    try {
      // Call backend validateRedemption to finalize
      final callable = FirebaseFunctions.instance.httpsCallable('validateRedemption');
      
      final result = await callable.call({
        'offerId': widget.offerId,
        'tokenNonce': widget.tokenNonce,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['redemptionId'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['error'] ?? 'Redemption failed'}')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Redemption')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Offer ID: ${widget.offerId}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Points: ${widget.pointsCost}'),
                    const SizedBox(height: 8),
                    Text('Display Code: ${widget.displayCode}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _confirmRedemption,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Complete Redemption'),
            ),
          ],
        ),
      ),
    );
  }
}
