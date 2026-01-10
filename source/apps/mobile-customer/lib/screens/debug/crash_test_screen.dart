import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Debug-only screen for testing Crashlytics integration
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
        title: const Text('Crashlytics Test'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bug_report, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Observability Test Tools',
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
                FirebaseCrashlytics.instance.log('User triggered test crash');
                FirebaseCrashlytics.instance.setCustomKey('crash_trigger', 'manual');
                
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
                  throw Exception('Test non-fatal exception');
                } catch (e, stack) {
                  FirebaseCrashlytics.instance.recordError(
                    e,
                    stack,
                    reason: 'Test non-fatal error recording',
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
                FirebaseCrashlytics.instance.log('Breadcrumb test: User action');
                FirebaseCrashlytics.instance.setCustomKey('test_breadcrumb', DateTime.now().toIso8601String());
                
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
