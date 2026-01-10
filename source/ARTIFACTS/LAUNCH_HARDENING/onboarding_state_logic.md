# Onboarding State Logic

**Module**: C1 — User Onboarding  
**Purpose**: State management implementation specification  
**Technology**: shared_preferences + StatefulWidget  
**Status**: Complete

---

## State Storage Schema

### SharedPreferences Keys

```dart
// Onboarding completion state
static const String KEY_ONBOARDING_COMPLETED = 'onboarding_completed';
static const String KEY_ONBOARDING_COMPLETED_AT = 'onboarding_completed_at';
static const String KEY_ONBOARDING_SKIPPED = 'onboarding_skipped';

// Permission state
static const String KEY_NOTIFICATION_PERMISSION_GRANTED = 'notification_permission_granted';
static const String KEY_NOTIFICATION_PERMISSION_ASKED = 'notification_permission_asked';

// User tracking
static const String KEY_USER_TYPE = 'user_type'; // 'customer' or 'merchant'
static const String KEY_ONBOARDING_VERSION = 'onboarding_version'; // '1.0'
```

### Data Types
```dart
onboarding_completed: bool (default: false)
onboarding_completed_at: String (ISO8601 timestamp)
onboarding_skipped: bool (default: false)
notification_permission_granted: bool (default: false)
notification_permission_asked: bool (default: false)
user_type: String ('customer' | 'merchant')
onboarding_version: String ('1.0')
```

---

## Service Class Implementation

### OnboardingService (lib/services/onboarding_service.dart)

```dart
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  // Keys
  static const String _keyCompleted = 'onboarding_completed';
  static const String _keyCompletedAt = 'onboarding_completed_at';
  static const String _keySkipped = 'onboarding_skipped';
  static const String _keyNotificationGranted = 'notification_permission_granted';
  static const String _keyNotificationAsked = 'notification_permission_asked';
  static const String _keyUserType = 'user_type';
  static const String _keyVersion = 'onboarding_version';
  static const String _currentVersion = '1.0';

  /// Check if onboarding should be shown
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if completed
    final completed = prefs.getBool(_keyCompleted) ?? false;
    if (completed) {
      // Check version - if onboarding updated, show again
      final savedVersion = prefs.getString(_keyVersion);
      if (savedVersion != _currentVersion) {
        return true; // New onboarding version available
      }
      return false;
    }
    
    return true; // Not completed, show onboarding
  }

  /// Mark onboarding as completed
  static Future<void> markCompleted({
    required bool notificationGranted,
    required String userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyCompleted, true);
    await prefs.setString(_keyCompletedAt, DateTime.now().toIso8601String());
    await prefs.setBool(_keyNotificationGranted, notificationGranted);
    await prefs.setBool(_keyNotificationAsked, true);
    await prefs.setString(_keyUserType, userType);
    await prefs.setString(_keyVersion, _currentVersion);
    await prefs.setBool(_keySkipped, false);
  }

  /// Mark onboarding as skipped
  static Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkipped, true);
    // Note: onboarding_completed remains false
  }

  /// Reset onboarding (for replay)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyCompleted);
    await prefs.remove(_keyCompletedAt);
    await prefs.remove(_keySkipped);
    // Keep permission state - don't reset notification flags
  }

  /// Get onboarding status
  static Future<OnboardingStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    return OnboardingStatus(
      completed: prefs.getBool(_keyCompleted) ?? false,
      completedAt: prefs.getString(_keyCompletedAt),
      skipped: prefs.getBool(_keySkipped) ?? false,
      notificationGranted: prefs.getBool(_keyNotificationGranted) ?? false,
      notificationAsked: prefs.getBool(_keyNotificationAsked) ?? false,
      userType: prefs.getString(_keyUserType),
      version: prefs.getString(_keyVersion),
    );
  }

  /// Check if notification permission was already asked
  static Future<bool> wasNotificationAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationAsked) ?? false;
  }
}

/// Onboarding status data class
class OnboardingStatus {
  final bool completed;
  final String? completedAt;
  final bool skipped;
  final bool notificationGranted;
  final bool notificationAsked;
  final String? userType;
  final String? version;

  OnboardingStatus({
    required this.completed,
    this.completedAt,
    required this.skipped,
    required this.notificationGranted,
    required this.notificationAsked,
    this.userType,
    this.version,
  });
}
```

---

## Screen State Management

### OnboardingScreen StatefulWidget

```dart
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Customer: 3 screens, Merchant: 4 screens
  int get _totalPages => _isCustomerApp() ? 3 : 4;

  bool _isCustomerApp() {
    // Detect from app type or context
    // For Customer app, return true
    // For Merchant app, return false
    return true; // Placeholder - detect from app context
  }

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  /// Navigate to next page
  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Handle skip button
  Future<void> _handleSkip() async {
    await OnboardingService.markSkipped();
    if (mounted) {
      _navigateToAuth();
    }
  }

  /// Handle completion (from last screen)
  Future<void> _handleComplete({required bool notificationGranted}) async {
    setState(() => _isLoading = true);

    try {
      await OnboardingService.markCompleted(
        notificationGranted: notificationGranted,
        userType: _isCustomerApp() ? 'customer' : 'merchant',
      );

      if (mounted) {
        _navigateToAuth();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Navigate to authentication screen
  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Page view with screens
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: _buildPages(),
            ),

            // Skip button (top-right)
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _isLoading ? null : _handleSkip,
                child: const Text('Skip'),
              ),
            ),

            // Page indicators (bottom)
            if (_currentPage < _totalPages - 1)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalPages,
                    (index) => _buildPageIndicator(index),
                  ),
                ),
              ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    if (_isCustomerApp()) {
      return [
        CustomerWelcomeScreen(onNext: _nextPage),
        CustomerHowItWorksScreen(onNext: _nextPage),
        CustomerNotificationScreen(onComplete: _handleComplete),
      ];
    } else {
      return [
        MerchantWelcomeScreen(onNext: _nextPage),
        MerchantCreateOffersScreen(onNext: _nextPage),
        MerchantValidateRedemptionsScreen(onNext: _nextPage),
        MerchantNotificationScreen(onComplete: _handleComplete),
      ];
    }
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
```

---

## Notification Permission Flow State

### NotificationPrimingScreen State Logic

```dart
class NotificationPrimingScreen extends StatefulWidget {
  final Function(bool granted) onComplete;

  const NotificationPrimingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<NotificationPrimingScreen> createState() => _NotificationPrimingScreenState();
}

class _NotificationPrimingScreenState extends State<NotificationPrimingScreen> {
  bool _isRequesting = false;

  /// Request notification permission
  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);

    try {
      // Request permission via Firebase Messaging
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

      // Track analytics
      await FirebaseAnalytics.instance.logEvent(
        name: 'notification_permission_result',
        parameters: {'granted': granted},
      );

      // Complete onboarding with permission status
      widget.onComplete(granted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission request failed: $e')),
        );
      }
      // Complete as not granted
      widget.onComplete(false);
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  /// Skip permission (maybe later)
  void _skipPermission() {
    widget.onComplete(false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Icon(
            Icons.notifications_active_outlined,
            size: 120,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Stay Updated',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            'Get notified about new offers and earned points',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Benefits list
          _buildBenefit('New offer alerts'),
          _buildBenefit('Points earned confirmations'),
          _buildBenefit('Exclusive deals'),

          const Spacer(),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _requestPermission,
              child: _isRequesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enable Notifications'),
            ),
          ),
          const SizedBox(height: 16),

          // Secondary CTA
          TextButton(
            onPressed: _isRequesting ? null : _skipPermission,
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
```

---

## Main.dart Integration

### Check Logic on App Launch

```dart
class UrbanPointsCustomerApp extends StatelessWidget {
  const UrbanPointsCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Points Lebanon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A859),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: OnboardingService.shouldShowOnboarding(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Show onboarding if needed
          if (snapshot.data == true) {
            return const OnboardingScreen();
          }

          // Otherwise, check authentication
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (authSnapshot.hasData) {
                return const CustomerHomePage();
              }

              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
```

---

## Settings Screen Replay Integration

### Add to Settings Screen

```dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _replayOnboarding(BuildContext context) async {
    // Confirm action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Tutorial Again?'),
        content: const Text('This will show you the app tutorial from the beginning.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Reset onboarding state
    await OnboardingService.resetOnboarding();

    // Navigate to onboarding
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ... other settings

          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('View Tutorial Again'),
            subtitle: const Text('Replay the app walkthrough'),
            onTap: () => _replayOnboarding(context),
          ),

          // ... other settings
        ],
      ),
    );
  }
}
```

---

## State Transition Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   APP LAUNCH                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Check SharedPrefs     │
              │ onboarding_completed  │
              └───────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
            [false]              [true]
                │                   │
                ▼                   ▼
    ┌──────────────────┐   ┌──────────────────┐
    │ State: SHOW      │   │ State: HIDE      │
    │ OnboardingScreen │   │ Check Auth       │
    └──────────────────┘   └──────────────────┘
                │
                ▼
    ┌──────────────────────────┐
    │ Page State Machine       │
    │ currentPage: int (0-2/3) │
    └──────────────────────────┘
                │
      ┌─────────┼─────────┐
      │         │         │
  [Screen 1] [Screen 2] [Screen 3/4]
      │         │         │
      ▼         ▼         ▼
   [Next]    [Next]  [Permission]
                          │
                ┌─────────┴─────────┐
                │                   │
          [Enable]            [Skip]
                │                   │
                ▼                   ▼
    [System Permission      [Skip Permission]
     Dialog]                        │
                │                   │
                ▼                   ▼
    [Save granted=true]  [Save granted=false]
                │                   │
                └───────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Save to SharedPrefs:  │
              │ - onboarding_completed│
              │ - completed_at        │
              │ - notification_granted│
              │ - user_type           │
              │ - version             │
              └───────────────────────┘
                          │
                          ▼
                [Navigate to Auth]
```

---

## State Validation Rules

### Invariants
1. `onboarding_completed` can only transition from `false` → `true`, never reverse (except manual reset)
2. If `onboarding_skipped == true`, then `onboarding_completed` must be `false`
3. `notification_permission_asked` can only transition from `false` → `true`
4. `onboarding_completed_at` must be ISO8601 format
5. `user_type` must be one of: `'customer'`, `'merchant'`, or `null`

### State Consistency Checks
```dart
Future<bool> validateState() async {
  final status = await OnboardingService.getStatus();
  
  // Rule 1: If completed, must have timestamp
  if (status.completed && status.completedAt == null) {
    return false;
  }
  
  // Rule 2: If skipped, cannot be completed
  if (status.skipped && status.completed) {
    return false;
  }
  
  // Rule 3: If notification granted, must have been asked
  if (status.notificationGranted && !status.notificationAsked) {
    return false;
  }
  
  return true;
}
```

---

## Performance Considerations

### SharedPreferences Access
- Read once on app launch (cached in memory)
- Write only on state changes (2-3 times max per onboarding session)
- No blocking UI - all reads/writes use `await` in `async` functions

### Memory Usage
- PageController: ~1KB
- State variables: <100 bytes
- Cached preferences: ~500 bytes

### Battery Impact
- Minimal - no background tasks
- No continuous polling
- Permission request: One-time system call

---

**Status**: ✅ STATE LOGIC SPECIFICATION COMPLETE  
**Implementation Effort**: 4-6 hours  
**Testing Priority**: High (critical user flow)  
**Risk Level**: Low (simple state, no backend dependency)
