# Onboarding Screen Map

**Module**: C1 — User Onboarding  
**Purpose**: Visual navigation map for onboarding flows  
**Status**: Complete

---

## Customer App Screen Map

```
┌─────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                              │
└─────────────────────────────────────────────────────────────────┘
                              ▼
                   [Check onboarding_completed]
                              ▼
                    ┌─────────┴─────────┐
                    │                   │
                 [false]             [true]
                    │                   │
                    ▼                   ▼
        ┌───────────────────┐    ┌──────────────┐
        │  ONBOARDING FLOW  │    │  AUTH CHECK  │
        └───────────────────┘    └──────────────┘
                    │                   │
                    │                   ▼
                    │            [User logged in?]
                    │                   │
                    │          ┌────────┴────────┐
                    │          │                 │
                    │        [Yes]             [No]
                    │          │                 │
                    │          ▼                 ▼
                    │    ┌─────────┐      ┌──────────┐
                    │    │  HOME   │      │  LOGIN   │
                    │    └─────────┘      └──────────┘
                    │
                    ▼
        ┌───────────────────────────────────────┐
        │  SCREEN 1: WELCOME & VALUE            │
        │  • Title: "Welcome to Urban Points"    │
        │  • 3 Key Benefits                      │
        │  • Illustration: Shopping + Points     │
        │  • CTA: "Next"                         │
        │  • Footer: "Skip" ──────────────────┐ │
        └───────────────────────────────────────┘ │
                    │                             │
                 [Next]                           │
                    ▼                             │
        ┌───────────────────────────────────────┐ │
        │  SCREEN 2: HOW IT WORKS               │ │
        │  • Title: "Simple & Rewarding"         │ │
        │  • 3 Steps Illustration                │ │
        │  • Shop → Show QR → Earn Points        │ │
        │  • CTA: "Next"                         │ │
        │  • Footer: "Skip" ──────────────────┐ │ │
        └───────────────────────────────────────┘ │ │
                    │                             │ │
                 [Next]                           │ │
                    ▼                             │ │
        ┌───────────────────────────────────────┐ │ │
        │  SCREEN 3: NOTIFICATION PERMISSION    │ │ │
        │  • Title: "Stay Updated"               │ │ │
        │  • Benefits: Offers, Points, Deals     │ │ │
        │  • CTA: "Enable Notifications"         │ │ │
        │  • Secondary: "Maybe Later"            │ │ │
        └───────────────────────────────────────┘ │ │
                    │                             │ │
          ┌─────────┴─────────┐                  │ │
          │                   │                  │ │
   [Enable Notifications]  [Maybe Later]        │ │
          │                   │                  │ │
          ▼                   │                  │ │
    [System Permission        │                  │ │
     Dialog]                  │                  │ │
          │                   │                  │ │
          ▼                   ▼                  │ │
    [Mark Complete]     [Mark Complete]         │ │
          │                   │                  │ │
          └───────────────────┴──────────────────┘ │
                              │                    │
                              ▼                    │
                    [onboarding_completed = true]  │
                              │                    │
                              ▼                    │
                       [Navigate to               │
                        LoginScreen]               │
                              │                    │
                              └────────────────────┘
                              (All paths converge)
                              ▼
                        [LOGIN SCREEN]
```

---

## Merchant App Screen Map

```
┌─────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                              │
└─────────────────────────────────────────────────────────────────┘
                              ▼
                   [Check onboarding_completed]
                              ▼
                    ┌─────────┴─────────┐
                    │                   │
                 [false]             [true]
                    │                   │
                    ▼                   ▼
        ┌───────────────────┐    ┌──────────────┐
        │  ONBOARDING FLOW  │    │  AUTH CHECK  │
        └───────────────────┘    └──────────────┘
                    │                   │
                    │                   ▼
                    │            [User logged in?]
                    │                   │
                    │          ┌────────┴────────┐
                    │          │                 │
                    │        [Yes]             [No]
                    │          │                 │
                    │          ▼                 ▼
                    │    ┌─────────┐      ┌──────────┐
                    │    │  HOME   │      │  LOGIN   │
                    │    └─────────┘      └──────────┘
                    │
                    ▼
        ┌───────────────────────────────────────┐
        │  SCREEN 1: WELCOME                    │
        │  • Title: "Welcome - Merchant"         │
        │  • Business Growth Focus               │
        │  • 3 Benefits: Customers, Visits, ROI  │
        │  • CTA: "Get Started"                  │
        │  • Footer: "Skip" ──────────────────┐ │
        └───────────────────────────────────────┘ │
                    │                             │
              [Get Started]                       │
                    ▼                             │
        ┌───────────────────────────────────────┐ │
        │  SCREEN 2: CREATE OFFERS              │ │
        │  • Title: "Create Irresistible Offers"│ │
        │  • Offer card mockup                   │ │
        │  • Set points, upload, track           │ │
        │  • CTA: "Next"                         │ │
        │  • Footer: "Skip" ──────────────────┐ │ │
        └───────────────────────────────────────┘ │ │
                    │                             │ │
                 [Next]                           │ │
                    ▼                             │ │
        ┌───────────────────────────────────────┐ │ │
        │  SCREEN 3: VALIDATE REDEMPTIONS       │ │ │
        │  • Title: "Quick QR Validation"        │ │ │
        │  • Phone scanning QR illustration      │ │ │
        │  • Benefits: Instant, Fraud, Analytics │ │ │
        │  • CTA: "Next"                         │ │ │
        │  • Footer: "Skip" ──────────────────┐ │ │ │
        └───────────────────────────────────────┘ │ │ │
                    │                             │ │ │
                 [Next]                           │ │ │
                    ▼                             │ │ │
        ┌───────────────────────────────────────┐ │ │ │
        │  SCREEN 4: NOTIFICATION PERMISSION    │ │ │ │
        │  • Title: "Stay Connected"             │ │ │ │
        │  • Benefits: Redemptions, Approvals    │ │ │ │
        │  • CTA: "Enable Notifications"         │ │ │ │
        │  • Secondary: "Skip for Now"           │ │ │ │
        └───────────────────────────────────────┘ │ │ │
                    │                             │ │ │
          ┌─────────┴─────────┐                  │ │ │
          │                   │                  │ │ │
   [Enable Notifications] [Skip for Now]        │ │ │
          │                   │                  │ │ │
          ▼                   │                  │ │ │
    [System Permission        │                  │ │ │
     Dialog]                  │                  │ │ │
          │                   │                  │ │ │
          ▼                   ▼                  │ │ │
    [Mark Complete]     [Mark Complete]         │ │ │
          │                   │                  │ │ │
          └───────────────────┴──────────────────┘ │ │
                              │                    │ │
                              ▼                    │ │
                    [onboarding_completed = true]  │ │
                              │                    │ │
                              ▼                    │ │
                       [Navigate to               │ │
                        LoginScreen]               │ │
                              │                    │ │
                              └────────────────────┘ │
                              (All paths)            │
                              │                      │
                              └──────────────────────┘
                              ▼
                        [LOGIN SCREEN]
```

---

## Replay Flow (Both Apps)

```
┌─────────────────────────────────────────────────────────────────┐
│                       SETTINGS SCREEN                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    [Help & Support Section]
                              │
                              ▼
                   "View Tutorial Again" (tap)
                              │
                              ▼
              [Clear onboarding_completed flag]
                              │
                              ▼
                    [Navigate to Screen 1]
                              │
                              ▼
                    [Same flow as above]
                              │
                              ▼
                    [On completion, return to
                     previous screen or HomePage]
```

---

## Navigation Transitions

### Forward Navigation
- **Animation**: Slide from right to left
- **Duration**: 300ms
- **Curve**: `Curves.easeInOut`

### Backward Navigation
- **Animation**: Slide from left to right
- **Duration**: 300ms
- **Curve**: `Curves.easeInOut`

### Skip Navigation
- **Animation**: Fade out current screen, fade in LoginScreen
- **Duration**: 200ms
- **Curve**: `Curves.easeOut`

---

## State Persistence Points

```
Screen 1 → [No persistence needed]
Screen 2 → [No persistence needed]
Screen 3/4 (Permission) → [Save notification_permission_granted]
Completion → [Save onboarding_completed, onboarding_completed_at]
Skip → [No completion flag saved]
```

---

## Screen Dimensions & Layout

### Aspect Ratio Handling
- **Portrait Primary**: 9:16 (standard mobile)
- **Landscape**: Show horizontal scroll or stack vertically
- **Safe Area**: All content within safe area bounds

### Component Positioning
```
┌─────────────────────────────────┐
│ [Skip] ──────────────────────── │ ← Top-right, 16dp margin
│                                 │
│          [Illustration]          │ ← Top 40% of screen
│                                 │
│           [Title]               │ ← H4 typography
│          [Subtitle]             │ ← Body1 typography
│                                 │
│      • [Key Point 1]            │
│      • [Key Point 2]            │ ← Body2, left-aligned
│      • [Key Point 3]            │
│                                 │
│     [● ○ ○]                     │ ← Page indicators (if >1 screen)
│                                 │
│   ┌────────────────────────┐   │
│   │    [Primary CTA]       │   │ ← 16dp from bottom
│   └────────────────────────┘   │
└─────────────────────────────────┘
```

---

## Analytics Event Map

```
[App Launch]
     │
     ▼
[onboarding_started] ────────────────────────────────────┐
     │                                                     │
     ▼                                                     │
[onboarding_screen_viewed: screen_1] ──────────────────┐ │
     │                                                   │ │
     │ [Next] or [Skip]                                 │ │
     │                                                   │ │
     ├─ [Next] ──> [onboarding_screen_viewed: screen_2] │ │
     │                   │                               │ │
     │                   ├─ [Next] ──> [screen_3]       │ │
     │                   │                   │           │ │
     │                   │            [Enable/Skip]      │ │
     │                   │                   │           │ │
     │                   │            [onboarding_       │ │
     │                   │             completed]        │ │
     │                   │                               │ │
     └─ [Skip] ───────────────────────────────────────────┘
                         │                               │
                         └───────────────────────────────┘
                                     │
                                     ▼
                          [Navigate to LoginScreen]
```

---

## Integration Points

### main.dart Entry
```dart
// Check in build() method
FutureBuilder<bool>(
  future: OnboardingService.shouldShowOnboarding(),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return OnboardingScreen();
    }
    return AuthWrapper(); // Existing auth check
  },
)
```

### Settings Screen Link
```dart
ListTile(
  leading: Icon(Icons.school_outlined),
  title: Text('View Tutorial Again'),
  onTap: () async {
    await OnboardingService.resetOnboarding();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnboardingScreen()),
    );
  },
)
```

---

## Screen Count Summary

**Customer App**: 3 screens + Skip option  
**Merchant App**: 4 screens + Skip option  
**Replay**: Same screens as initial flow  

**Total Unique Screens to Build**: 7 (3 Customer + 4 Merchant)  
**Reusable Components**: PageIndicator, SkipButton, PrimaryButton

---

**Status**: ✅ SCREEN MAP COMPLETE  
**Coverage**: 100% of onboarding user journeys  
**Implementation Ready**: Yes (spec provides all navigation logic)
