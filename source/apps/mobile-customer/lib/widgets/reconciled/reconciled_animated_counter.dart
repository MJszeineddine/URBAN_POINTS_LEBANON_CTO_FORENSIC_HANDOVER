import 'package:flutter/material.dart';

/// Reconciled from legacy urban_points_customer
/// Source: /home/user/urban_points_customer/lib/widgets/animated_counter.dart
/// Purpose: Animated counter for points display
/// Dependencies: None (pure Flutter)
/// Integration: Use in points balance cards
///
/// Usage:
/// ```dart
/// // Instead of static Text:
/// // OLD: Text('${customer.pointsBalance}')
/// // NEW: ReconciledAnimatedCounter(
/// //        value: customer.pointsBalance,
/// //        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
/// //      )
/// ```

class ReconciledAnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  
  const ReconciledAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<ReconciledAnimatedCounter> createState() => _ReconciledAnimatedCounterState();
}

class _ReconciledAnimatedCounterState extends State<ReconciledAnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ReconciledAnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _oldValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _animation.value.round().toString(),
          style: widget.style,
        );
      },
    );
  }
}
