import 'package:flutter/material.dart';

/// Reconciled from legacy urban_points_customer
/// Source: /home/user/urban_points_customer/lib/widgets/offline_banner.dart
/// Purpose: Display offline mode indicator banner
/// 
/// ⚠️ DEPENDENCY ISSUE: Original requires Provider + ConnectivityService
/// ⚠️ STATUS: STUB ONLY - Not wired, needs connectivity monitoring
///
/// TODO: To activate this widget:
/// 1. Add dependency: connectivity_plus: ^5.0.0 to pubspec.yaml
/// 2. Create connectivity service or use stream-based monitoring
/// 3. Pass isOnline state as parameter instead of Provider
///
/// Usage (once wired):
/// ```dart
/// Scaffold(
///   body: ReconciledOfflineBanner(
///     isOnline: true, // Connect to connectivity stream
///     child: YourContent(),
///   ),
/// )
/// ```

class ReconciledOfflineBanner extends StatelessWidget {
  final Widget child;
  final bool isOnline;

  const ReconciledOfflineBanner({
    super.key,
    required this.child,
    this.isOnline = true, // Default to online
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.red[700],
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Offline Mode',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
