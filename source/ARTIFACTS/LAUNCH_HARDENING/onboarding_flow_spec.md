# User Onboarding Flow Specification

**Module**: C1 — User Onboarding (P0)  
**Target Apps**: Customer App, Merchant App  
**Status**: Specification Complete  
**Priority**: P0 (Store Approval + First-Run UX)

---

## Overview

First-time user experience for both Customer and Merchant apps to:
1. Explain app value proposition
2. Prime notification permissions
3. Reduce abandonment during signup
4. Enable skip/replay functionality

---

## Customer App Onboarding Flow

### Trigger Condition
- First app launch after installation
- Check: `SharedPreferences.getBool('onboarding_completed') == null || false`

### Screen Sequence (3 screens)

**Screen 1: Welcome & Value**
```
Title: "Welcome to Urban Points Lebanon"
Subtitle: "Earn points at your favorite local stores"

Visual: Illustration of customer with shopping bags + points badge
Key Points:
• Shop at partner merchants
• Earn points with every purchase
• Redeem for exclusive offers

CTA: "Next"
Footer: "Skip" link (right-aligned)
```

**Screen 2: How It Works**
```
Title: "Simple & Rewarding"
Subtitle: "Three easy steps to start earning"

Visual: 3-step process illustration
Steps:
1. 🏪 Visit partner merchant → "Shop at any partner store"
2. 📱 Show QR code → "Present your QR code at checkout"
3. 🎁 Earn points → "Collect points and unlock offers"

CTA: "Next"
Footer: "Skip" link
```

**Screen 3: Notification Permission Priming**
```
Title: "Stay Updated"
Subtitle: "Get notified about new offers and earned points"

Visual: Phone with notification bubbles
Benefits:
• New offer alerts
• Points earned confirmations
• Exclusive deals

CTA: "Enable Notifications" (primary)
Secondary CTA: "Maybe Later" (text button)

Action:
- "Enable Notifications" → Request system permission → Mark complete
- "Maybe Later" → Mark complete without permission
```

### Completion Action
```dart
await SharedPreferences.getInstance().then((prefs) {
  prefs.setBool('onboarding_completed', true);
  prefs.setString('onboarding_completed_at', DateTime.now().toIso8601String());
});
// Navigate to: LoginScreen or HomePage (if already authenticated)
```

---

## Merchant App Onboarding Flow

### Trigger Condition
- First app launch after installation
- Check: `SharedPreferences.getBool('onboarding_completed') == null || false`

### Screen Sequence (4 screens)

**Screen 1: Welcome**
```
Title: "Welcome to Urban Points - Merchant"
Subtitle: "Grow your business with Lebanon's loyalty network"

Visual: Store icon with growth arrow
Key Points:
• Attract new customers
• Increase repeat visits
• Track customer loyalty

CTA: "Get Started"
Footer: "Skip" link
```

**Screen 2: Create Offers**
```
Title: "Create Irresistible Offers"
Subtitle: "Drive traffic with points-based promotions"

Visual: Offer card mockup
Features:
• Set points required
• Upload offer images
• Track redemptions

CTA: "Next"
Footer: "Skip" link
```

**Screen 3: Validate Redemptions**
```
Title: "Quick QR Validation"
Subtitle: "Scan customer QR codes to award points"

Visual: Phone scanning QR code
Benefits:
• Instant validation
• Fraud protection
• Real-time analytics

CTA: "Next"
Footer: "Skip" link
```

**Screen 4: Notification Permission Priming**
```
Title: "Stay Connected"
Subtitle: "Get notified about redemptions and analytics"

Visual: Phone with merchant notifications
Benefits:
• New redemption alerts
• Offer approval status
• Performance insights

CTA: "Enable Notifications" (primary)
Secondary CTA: "Skip for Now" (text button)

Action:
- "Enable Notifications" → Request system permission → Mark complete
- "Skip for Now" → Mark complete without permission
```

### Completion Action
```dart
await SharedPreferences.getInstance().then((prefs) {
  prefs.setBool('onboarding_completed', true);
  prefs.setString('onboarding_completed_at', DateTime.now().toIso8601String());
  prefs.setString('user_type', 'merchant');
});
// Navigate to: LoginScreen or HomePage (if already authenticated)
```

---

## Skip Logic

### User Taps "Skip"
- No mark as complete
- Navigate directly to LoginScreen
- Show simplified tooltip on first critical action:
  - Customer: "Tap here to view your QR code"
  - Merchant: "Tap here to scan customer codes"

### Re-triggering Onboarding
- Settings screen option: "View Tutorial Again"
- Action: Clear `onboarding_completed` flag → Restart from Screen 1

---

## Replay Functionality

### Settings Integration (Both Apps)
```
Settings Screen > Help Section
├── "View Tutorial Again"
└── "Help & Support"
```

### Replay Logic
```dart
Future<void> replayOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', false);
  // Navigate to onboarding flow
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => OnboardingScreen()),
  );
}
```

---

## Completion Flag Logic

### Storage Mechanism
**Technology**: `shared_preferences` package (already in use)

**Keys**:
- `onboarding_completed` (bool): true when completed
- `onboarding_completed_at` (String): ISO8601 timestamp
- `onboarding_skipped` (bool): true if user skipped
- `notification_permission_granted` (bool): true if granted during onboarding

### Check Logic (main.dart Integration)
```dart
Future<bool> _shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') != true;
}

// In build() method
if (await _shouldShowOnboarding()) {
  return OnboardingScreen();
} else {
  return StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    // ... existing auth check
  );
}
```

---

## Analytics Tracking

### Events to Track (Firebase Analytics)
```dart
// Onboarding started
await FirebaseAnalytics.instance.logEvent(
  name: 'onboarding_started',
  parameters: {'app_type': 'customer'}, // or 'merchant'
);

// Screen progression
await FirebaseAnalytics.instance.logEvent(
  name: 'onboarding_screen_viewed',
  parameters: {
    'screen_number': 2,
    'screen_name': 'how_it_works',
  },
);

// Completion
await FirebaseAnalytics.instance.logEvent(
  name: 'onboarding_completed',
  parameters: {
    'completion_type': 'full', // or 'skipped'
    'notification_permission': true, // or false
  },
);
```

---

## Technical Requirements

### Dependencies (Already Available)
```yaml
dependencies:
  shared_preferences: ^2.5.3  # ✅ Already in use
  firebase_analytics: ^11.3.3  # ✅ Already in use (if analytics enabled)
```

### File Structure
```
lib/
├── screens/
│   └── onboarding/
│       ├── onboarding_screen.dart      # Main coordinator
│       ├── welcome_screen.dart         # Screen 1
│       ├── how_it_works_screen.dart    # Screen 2
│       ├── notification_priming_screen.dart  # Screen 3/4
│       └── onboarding_page_indicator.dart    # Dot indicators
└── services/
    └── onboarding_service.dart         # State management
```

---

## UI/UX Guidelines

### Design Consistency
- Use app's existing color scheme (Customer: #00A859, Merchant: #0066CC)
- Material Design 3 components
- Illustrations: Simple, flat design (can use placeholder icons initially)
- Typography: Existing app font stack

### Accessibility
- Screen reader support (Semantics widgets)
- Minimum touch target size: 48x48dp
- Color contrast ratio ≥ 4.5:1
- Support text scaling

### Animation
- Page transitions: Slide left (forward), slide right (back)
- Duration: 300ms with easeInOut curve
- Skip button: Fade in after 2s on each screen

---

## Implementation Priority

**Phase 1 (Pre-Launch)**: Core flow + skip logic
**Phase 2 (Post-Launch)**: Analytics + replay functionality
**Phase 3 (Optimization)**: A/B testing different content

---

## Validation Checklist

- [ ] Onboarding triggers on first launch
- [ ] Skip button navigates correctly
- [ ] Notification permission priming before system prompt
- [ ] Completion flag persists across app restarts
- [ ] Replay functionality accessible from Settings
- [ ] No onboarding shown to returning users
- [ ] Smooth page transitions
- [ ] All text localized (if i18n enabled)

---

## Risk Assessment

**Low Risk**:
- Uses existing dependencies
- No backend changes
- Simple state management
- Easily testable

**Potential Issues**:
- Notification permission denial → User can re-enable in Settings
- Onboarding too long → Skip option mitigates

---

**Status**: ✅ SPECIFICATION COMPLETE  
**Implementation Effort**: 8-12 hours (including testing)  
**Store Impact**: HIGH (reduces abandonment, primes permissions properly)
