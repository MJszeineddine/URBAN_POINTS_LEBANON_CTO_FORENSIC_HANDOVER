import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class WhatsAppOTPScreen extends StatefulWidget {
  final String phoneNumber;
  
  const WhatsAppOTPScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<WhatsAppOTPScreen> createState() => _WhatsAppOTPScreenState();
}

class _WhatsAppOTPScreenState extends State<WhatsAppOTPScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _resendCountdown = 0;
  String? _error;
  final _functions = FirebaseFunctions.instance;

  @override
  void initState() {
    super.initState();
    _sendOTP();
  }

  Future<void> _sendOTP() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await _functions.httpsCallable('sendWhatsAppOTP').call({
        'phoneNumber': widget.phoneNumber,
      });

      if (result.data['success']) {
        setState(() {
          _error = null;
          _resendCountdown = 60;
        });
        _startCountdown();
      } else {
        setState(() {
          _error = result.data['error'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          }
        });
      }
      return _resendCountdown > 0;
    });
  }

  Future<void> _verifyOTP() async {
    if (_codeController.text.isEmpty) {
      setState(() => _error = 'Please enter the OTP code');
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final result = await _functions.httpsCallable('verifyWhatsAppOTP').call({
        'phoneNumber': widget.phoneNumber,
        'code': _codeController.text,
      });

      if (result.data['success'] && result.data['valid']) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = result.data['error'] ?? 'Invalid OTP code';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Verification failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify with WhatsApp'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Code Sent',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a 6-digit code to ${widget.phoneNumber} via WhatsApp',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: _error,
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  _verifyOTP();
                }
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify Code'),
              ),
            ),
            const SizedBox(height: 24),
            if (_resendCountdown > 0)
              Text(
                'Resend code in $_resendCountdown seconds',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
            else
              GestureDetector(
                onTap: _sendOTP,
                child: Text(
                  'Didn\'t receive the code? Resend',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
