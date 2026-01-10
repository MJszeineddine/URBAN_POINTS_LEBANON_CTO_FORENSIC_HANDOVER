import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Debug-only screen for testing Crashlytics integration (Merchant App)
/// Only accessible in debug mode (kDebugMode)
class CrashTestScreen extends StatelessWidget {
  const CrashTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Available')),
        body: const Center(
          child: Text('This screen is only available in debug mode'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crashlytics Test - Merchant'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bug_report, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Merchant App Observability Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'DEBUG MODE ONLY',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Log breadcrumb before crash
                FirebaseCrashlytics.instance.log('Merchant triggered test crash');
                FirebaseCrashlytics.instance.setCustomKey('crash_trigger', 'manual_merchant');
                FirebaseCrashlytics.instance.setCustomKey('merchant_screen', 'crash_test');
                
                // Trigger fatal crash
                FirebaseCrashlytics.instance.crash();
              },
              icon: const Icon(Icons.warning),
              label: const Text('Trigger Fatal Crash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Log non-fatal error
                try {
                  throw Exception('Merchant test non-fatal exception');
                } catch (e, stack) {
                  FirebaseCrashlytics.instance.recordError(
                    e,
                    stack,
                    reason: 'Merchant test non-fatal error recording',
                    fatal: false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Non-fatal error logged to Crashlytics'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.info),
              label: const Text('Log Non-Fatal Error'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Log breadcrumbs
                FirebaseCrashlytics.instance.log('Breadcrumb: Merchant action');
                FirebaseCrashlytics.instance.setCustomKey('merchant_breadcrumb', DateTime.now().toIso8601String());
                FirebaseCrashlytics.instance.setCustomKey('merchant_id', 'test_merchant_123');
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Breadcrumb logged'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text('Log Breadcrumb'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Note: Crashes will restart the app.\n'
                'View results in Firebase Console → Crashlytics',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
