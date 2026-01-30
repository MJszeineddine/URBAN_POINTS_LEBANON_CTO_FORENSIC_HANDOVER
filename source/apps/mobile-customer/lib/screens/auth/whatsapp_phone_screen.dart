import 'package:flutter/material.dart';
import 'whatsapp_otp_screen.dart';

class WhatsAppPhoneScreen extends StatefulWidget {
  const WhatsAppPhoneScreen({super.key});

  @override
  State<WhatsAppPhoneScreen> createState() => _WhatsAppPhoneScreenState();
}

class _WhatsAppPhoneScreenState extends State<WhatsAppPhoneScreen> {
  final _phoneController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validateAndProceed() {
    final phone = _phoneController.text.trim();
    
    // Validate Lebanese phone number format: +961 XXXXX XXX
    if (!phone.startsWith('+961')) {
      setState(() => _error = 'Phone must start with +961');
      return;
    }
    
    if (phone.length != 13) {
      setState(() => _error = 'Invalid Lebanese phone number');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WhatsAppOTPScreen(phoneNumber: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Verification'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.message,
              size: 64,
              color: const Color(0xFF25D366),
            ),
            const SizedBox(height: 24),
            Text(
              'Verify with WhatsApp',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your Lebanese phone number to receive a verification code via WhatsApp',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+961 XX XXX XXXX',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _validateAndProceed,
                child: const Text('Send Code via WhatsApp'),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why WhatsApp?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Fast and secure delivery\n• No SMS charges\n• Instant verification\n• Works worldwide',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
