import 'package:flutter/material.dart';

/// Reconciled from legacy urban_points_customer
/// Source: /home/user/urban_points_customer/lib/widgets/skeleton_loader.dart
/// Purpose: Animated skeleton loader for loading states
/// Dependencies: None (pure Flutter)
/// Integration: Replace CircularProgressIndicator in list views
///
/// Usage:
/// ```dart
/// // Replace loading spinner:
/// // OLD: CircularProgressIndicator()
/// // NEW: ReconciledSkeletonLoader(height: 80, borderRadius: BorderRadius.circular(12))
/// ```

class ReconciledSkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  
  const ReconciledSkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius,
  });

  @override
  State<ReconciledSkeletonLoader> createState() => _ReconciledSkeletonLoaderState();
}

class _ReconciledSkeletonLoaderState extends State<ReconciledSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0),
              end: Alignment(1.0 - _controller.value * 2, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ),
          ),
        );
      },
    );
  }
}
