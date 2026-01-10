import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'how_it_works_screen.dart';
import 'notification_priming_screen.dart';
import '../../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
      setState(() {
        _currentPage++;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentPage,
      children: [
        WelcomeScreen(onNext: _nextPage),
        HowItWorksScreen(onNext: _nextPage),
        NotificationPrimingScreen(onComplete: _completeOnboarding),
      ],
    );
  }
}
