import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyCompleted = 'onboarding_completed';

  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) != true;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
  }
}
