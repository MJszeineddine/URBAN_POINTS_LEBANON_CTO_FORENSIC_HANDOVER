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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _complete() async {
    await OnboardingService.markCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      children: [
        WelcomeScreen(onNext: _nextPage),
        HowItWorksScreen(onNext: _nextPage),
        NotificationPrimingScreen(onComplete: _complete),
      ],
    );
  }
}
