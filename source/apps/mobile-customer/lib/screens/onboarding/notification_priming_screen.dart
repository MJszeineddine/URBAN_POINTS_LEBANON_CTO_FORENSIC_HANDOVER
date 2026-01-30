import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationPrimingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const NotificationPrimingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_active,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Stay Updated',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Get notified about new offers and earned points',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _requestPermission(context),
                  child: const Text('Enable Notifications'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onComplete,
                child: const Text('Maybe Later'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      // Permission request failed, continue anyway
    }
    if (context.mounted) {
      onComplete();
    }
  }
}
