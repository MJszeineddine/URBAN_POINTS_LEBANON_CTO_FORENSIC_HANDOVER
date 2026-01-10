import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class QRGenerationScreen extends StatefulWidget {
  final String offerId;
  final String offerTitle;
  final int pointsRequired;
  final String merchantId;

  const QRGenerationScreen({
    super.key,
    required this.offerId,
    required this.offerTitle,
    required this.pointsRequired,
    required this.merchantId,
  });

  @override
  State<QRGenerationScreen> createState() => _QRGenerationScreenState();
}

class _QRGenerationScreenState extends State<QRGenerationScreen> {
  bool _isLoading = false;
  String? _qrToken;
  String? _displayCode;
  DateTime? _expiresAt;
  String? _error;
  Timer? _expiryTimer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQR() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _qrToken = null;
      _displayCode = null;
    });

    try {
      // Get current user ID from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get device identifier (simplified - in production use device_info_plus)
      final deviceHash = DateTime.now().millisecondsSinceEpoch.toString();

      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateSecureQRToken',
      );

      final idToken = await currentUser.getIdToken();
      final result = await callable.call(
        {
          'userId': currentUser.uid,
          'offerId': widget.offerId,
          'merchantId': widget.merchantId,
          'deviceHash': deviceHash,
          'partySize': 1,
        },
      );

      final data = result.data as Map<String, dynamic>;
      if (data['token'] != null) {
        setState(() {
          _qrToken = data['token'] as String;
          _displayCode = data['displayCode'] as String;
          _expiresAt = DateTime.parse(data['expiresAt'] as String);
          _isLoading = false;
        });

        _startExpiryTimer();
      } else {
        setState(() {
          _error = data['error'] as String? ?? 'Failed to generate QR code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiresAt == null) {
        timer.cancel();
        return;
      }

      final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _error = 'QR code expired';
          _qrToken = null;
        });
      } else {
        setState(() {
          _secondsRemaining = remaining;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redeem Offer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _qrToken == null
                ? _buildErrorState()
                : _qrToken != null
                    ? _buildQRDisplay()
                    : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateQR,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRDisplay() {
    final isExpiring = _secondsRemaining <= 10;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Offer info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    widget.offerTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars,
                        color: Color(0xFF00A859),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.pointsRequired} points',
                        style: const TextStyle(
                          color: Color(0xFF00A859),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isExpiring ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpiring ? Colors.red : Colors.green,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  color: isExpiring ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Expires in $_secondsRemaining seconds',
                  style: TextStyle(
                    color: isExpiring ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // QR Code
          Card(
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Show this to merchant',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: _qrToken!,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Display code as backup
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Backup Code',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _displayCode ?? '',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Merchant can enter this code manually',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Instructions
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionItem('1. Show QR code to merchant'),
                  _buildInstructionItem('2. Wait for merchant to scan'),
                  _buildInstructionItem('3. Code expires in 60 seconds'),
                  _buildInstructionItem('4. Generate new code if expired'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Regenerate button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _generateQR,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate New Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
