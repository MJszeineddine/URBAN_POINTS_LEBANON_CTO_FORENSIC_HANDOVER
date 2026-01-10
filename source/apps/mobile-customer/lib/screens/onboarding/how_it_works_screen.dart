import 'package:flutter/material.dart';

class HowItWorksScreen extends StatelessWidget {
  final VoidCallback onNext;

  const HowItWorksScreen({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStep(
                context,
                Icons.storefront,
                'Visit partner merchants',
              ),
              const SizedBox(height: 24),
              _buildStep(
                context,
                Icons.qr_code,
                'Show your QR code',
              ),
              const SizedBox(height: 24),
              _buildStep(
                context,
                Icons.stars,
                'Earn points & redeem offers',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
