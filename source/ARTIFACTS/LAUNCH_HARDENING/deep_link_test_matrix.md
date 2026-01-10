# Deep Link Test Matrix

**Module**: C3 — Deep Linking  
**Purpose**: Comprehensive test cases for deep link validation  
**Status**: Complete

---

## Test Scenarios

### Test Environment Setup

**Tools Required**:
- Android Debug Bridge (adb) for Android testing
- URL Schemes in iOS Simulator for iOS testing
- Firebase Dynamic Links console for universal links

**Test Commands**:

**Android**:
```bash
# Test custom scheme
adb shell am start -W -a android.intent.action.VIEW -d "urbanpoints://customer/offers/OFF_001"

# Test universal link
adb shell am start -W -a android.intent.action.VIEW -d "https://urbanpoints.app/c/offers/OFF_001"
```

**iOS Simulator**:
```bash
# Test custom scheme
xcrun simctl openurl booted "urbanpoints://customer/offers/OFF_001"

# Test universal link
xcrun simctl openurl booted "https://urbanpoints.app/c/offers/OFF_001"
```

---

## Customer App Test Cases

### TC-C1: Offer Detail Deep Link

**Objective**: Verify offer detail screen opens with correct offer ID

**Test Data**:
```
URL: urbanpoints://customer/offers/OFF_001
Expected: OfferDetailScreen(offerId: 'OFF_001')
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | App opens to offer detail | ☐ |
| 2 | Verify offer ID matches | Title, image, description for OFF_001 displayed | ☐ |
| 3 | Check back navigation | Pressing back goes to home screen | ☐ |
| 4 | Test with invalid offer ID | Error message or redirect to home | ☐ |

**Edge Cases**:
- Offer ID doesn't exist → Show "Offer not found" message
- Offer is inactive → Show "Offer no longer available"
- User not authenticated → Prompt login, then show offer

---

### TC-C2: QR Generation Deep Link

**Objective**: Verify QR screen opens directly

**Test Data**:
```
URL: urbanpoints://customer/qr
Expected: QRGenerationScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | QR generation screen opens | ☐ |
| 2 | Verify QR generates | 6-digit code and QR displayed | ☐ |
| 3 | Check expiration timer | Timer starts countdown | ☐ |
| 4 | Test offline mode | Error message "Connect to generate QR" | ☐ |
| 5 | Test unauthenticated user | Redirect to login, then QR screen | ☐ |

---

### TC-C3: Points History Deep Link

**Objective**: Verify history screen displays user transactions

**Test Data**:
```
URL: urbanpoints://customer/history
Expected: PointsHistoryScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Points history screen opens | ☐ |
| 2 | Verify balance displayed | Current points balance shown | ☐ |
| 3 | Verify transactions list | Recent redemptions displayed | ☐ |
| 4 | Test empty state | "No transactions yet" if no history | ☐ |
| 5 | Test offline mode | Cached history displayed with banner | ☐ |

---

### TC-C4: Merchant Detail Deep Link

**Objective**: Verify merchant profile opens with offers

**Test Data**:
```
URL: urbanpoints://customer/merchants/MERCH_001
Expected: MerchantDetailScreen(merchantId: 'MERCH_001')
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Merchant detail screen opens | ☐ |
| 2 | Verify merchant info | Name, logo, location displayed | ☐ |
| 3 | Verify offers list | Merchant's active offers shown | ☐ |
| 4 | Test invalid merchant ID | Error message or redirect to home | ☐ |

---

### TC-C5: Profile Deep Link

**Objective**: Verify profile screen opens for editing

**Test Data**:
```
URL: urbanpoints://customer/profile
Expected: ProfileScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Profile screen opens | ☐ |
| 2 | Verify user data displayed | Name, email, phone shown | ☐ |
| 3 | Test edit functionality | Can modify profile fields | ☐ |
| 4 | Test unauthenticated user | Redirect to login | ☐ |

---

### TC-C6: Home Screen Deep Link (Default)

**Objective**: Verify fallback route works

**Test Data**:
```
URL: urbanpoints://customer
Expected: CustomerHomePage()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Home screen opens | ☐ |
| 2 | Verify offers list displayed | Active offers shown | ☐ |
| 3 | Test navigation | Bottom nav functional | ☐ |

---

## Merchant App Test Cases

### TC-M1: QR Validation Deep Link

**Objective**: Verify validation screen opens for scanning

**Test Data**:
```
URL: urbanpoints://merchant/validate
Expected: ValidateRedemptionScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | QR validation screen opens | ☐ |
| 2 | Verify camera access | Camera preview displayed | ☐ |
| 3 | Test offline mode | Error "Internet required for validation" | ☐ |
| 4 | Test unauthenticated user | Redirect to login | ☐ |

---

### TC-M2: Offer Detail Deep Link

**Objective**: Verify merchant can view/edit their offer

**Test Data**:
```
URL: urbanpoints://merchant/offers/OFF_001
Expected: OfferDetailScreen(offerId: 'OFF_001')
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Offer detail screen opens | ☐ |
| 2 | Verify offer ownership | Only merchant's offer shown | ☐ |
| 3 | Test edit button | Navigates to edit screen | ☐ |
| 4 | Test invalid offer ID | Error or redirect | ☐ |

---

### TC-M3: Create Offer Deep Link

**Objective**: Verify create offer flow starts

**Test Data**:
```
URL: urbanpoints://merchant/offers/create
Expected: CreateOfferScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Create offer screen opens | ☐ |
| 2 | Verify form fields | All required fields displayed | ☐ |
| 3 | Test offline mode | Error "Connect to create offer" | ☐ |

---

### TC-M4: Dashboard Deep Link

**Objective**: Verify dashboard opens with stats

**Test Data**:
```
URL: urbanpoints://merchant/dashboard
Expected: MerchantHomePage()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Dashboard opens | ☐ |
| 2 | Verify stats displayed | Today's redemptions, points shown | ☐ |
| 3 | Test real-time updates | Stats update when online | ☐ |

---

### TC-M5: Redemption History Deep Link

**Objective**: Verify redemption list displays

**Test Data**:
```
URL: urbanpoints://merchant/redemptions
Expected: RedemptionHistoryScreen()
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Redemption history opens | ☐ |
| 2 | Verify transactions list | Recent validations shown | ☐ |
| 3 | Test filtering | Can filter by date/status | ☐ |

---

## Universal Links Test Cases

### TC-U1: HTTPS Universal Link (Customer)

**Objective**: Verify universal links work on web

**Test Data**:
```
URL: https://urbanpoints.app/c/offers/OFF_001
Expected: App opens if installed, else web page
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Click link in browser (app installed) | App opens to offer detail | ☐ |
| 2 | Click link in browser (app NOT installed) | Web page with app download link | ☐ |
| 3 | Test in email client | App opens from email link | ☐ |
| 4 | Test in SMS | App opens from SMS link | ☐ |

---

### TC-U2: HTTPS Universal Link (Merchant)

**Objective**: Verify merchant universal links

**Test Data**:
```
URL: https://urbanpoints.app/m/validate
Expected: Merchant app opens if installed
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Click link in browser | Merchant app opens to validation | ☐ |
| 2 | Test app switcher | Correct app (Customer vs Merchant) opens | ☐ |

---

## Query Parameters Test Cases

### TC-Q1: Action Parameter

**Objective**: Verify query parameters are parsed

**Test Data**:
```
URL: urbanpoints://customer/offers/OFF_001?action=redeem
Expected: Offer detail opens with redeem pre-selected
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Offer detail opens | ☐ |
| 2 | Verify action handled | Redeem button highlighted or auto-clicked | ☐ |

---

### TC-Q2: Source Tracking

**Objective**: Verify campaign source is tracked

**Test Data**:
```
URL: urbanpoints://customer/offers/OFF_001?source=email_campaign
Expected: Analytics event logged with source
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link | Offer opens | ☐ |
| 2 | Check Firebase Analytics | Event logged with source=email_campaign | ☐ |

---

## Push Notification Integration Test Cases

### TC-P1: Notification Tap (Customer)

**Objective**: Verify push notification opens correct screen

**Test Data**:
```
Push payload:
{
  "notification": {...},
  "data": {
    "deep_link": "urbanpoints://customer/offers/OFF_001"
  }
}
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Receive push notification | Notification appears | ☐ |
| 2 | Tap notification | App opens to offer detail | ☐ |
| 3 | Test app in background | Offer opens correctly | ☐ |
| 4 | Test app closed | App launches and opens offer | ☐ |

---

### TC-P2: Notification Tap (Merchant)

**Objective**: Verify merchant push opens validation

**Test Data**:
```
Push payload:
{
  "notification": {...},
  "data": {
    "deep_link": "urbanpoints://merchant/validate"
  }
}
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Receive redemption notification | Notification appears | ☐ |
| 2 | Tap notification | App opens to QR validation | ☐ |
| 3 | Test camera ready | Camera starts immediately | ☐ |

---

## Error Handling Test Cases

### TC-E1: Invalid Route

**Objective**: Verify graceful fallback for bad links

**Test Data**:
```
URL: urbanpoints://customer/invalid/route
Expected: Redirect to home with error message
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via invalid link | Home screen opens | ☐ |
| 2 | Verify error message | SnackBar shows "Invalid link" | ☐ |

---

### TC-E2: Malformed URL

**Objective**: Verify app doesn't crash on bad URL

**Test Data**:
```
URL: urbanpoints://customer//offers//
Expected: Graceful error handling
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via malformed link | App doesn't crash | ☐ |
| 2 | Verify fallback | Home screen opens | ☐ |

---

### TC-E3: Unauthenticated User

**Objective**: Verify login gate works

**Test Data**:
```
URL: urbanpoints://customer/qr
User state: Not logged in
Expected: Login screen, then QR screen after auth
```

| Step | Action | Expected Result | Pass/Fail |
|------|--------|----------------|-----------|
| 1 | Launch app via deep link (not logged in) | Login screen appears | ☐ |
| 2 | Complete login | Redirects to QR screen after login | ☐ |
| 3 | Verify pending route cleared | Subsequent logins go to home | ☐ |

---

## Cross-Platform Test Matrix

| Test Case | Android | iOS | Web | Priority |
|-----------|---------|-----|-----|----------|
| TC-C1: Offer Detail | ☐ | ☐ | ☐ | P0 |
| TC-C2: QR Screen | ☐ | ☐ | N/A | P0 |
| TC-C3: Points History | ☐ | ☐ | ☐ | P1 |
| TC-C4: Merchant Detail | ☐ | ☐ | ☐ | P1 |
| TC-C5: Profile | ☐ | ☐ | ☐ | P2 |
| TC-C6: Home | ☐ | ☐ | ☐ | P0 |
| TC-M1: QR Validation | ☐ | ☐ | N/A | P0 |
| TC-M2: Offer Detail | ☐ | ☐ | ☐ | P1 |
| TC-M3: Create Offer | ☐ | ☐ | ☐ | P1 |
| TC-M4: Dashboard | ☐ | ☐ | ☐ | P1 |
| TC-M5: Redemptions | ☐ | ☐ | ☐ | P2 |
| TC-U1: Universal Link | ☐ | ☐ | ☐ | P0 |
| TC-P1: Push Notification | ☐ | ☐ | N/A | P0 |
| TC-E1: Invalid Route | ☐ | ☐ | ☐ | P0 |

---

## Automated Test Template

### Flutter Integration Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Link Tests', () {
    testWidgets('TC-C1: Offer Detail Deep Link', (tester) async {
      // Setup
      await tester.pumpWidget(MyApp());
      
      // Simulate deep link
      final uri = Uri.parse('urbanpoints://customer/offers/OFF_001');
      await DeepLinkRouter.handleDeepLink(
        tester.element(find.byType(MyApp)),
        uri,
      );
      await tester.pumpAndSettle();
      
      // Verify navigation
      expect(find.byType(OfferDetailScreen), findsOneWidget);
      expect(find.text('OFF_001'), findsOneWidget); // Verify offer ID
    });

    testWidgets('TC-C2: QR Screen Deep Link', (tester) async {
      await tester.pumpWidget(MyApp());
      
      final uri = Uri.parse('urbanpoints://customer/qr');
      await DeepLinkRouter.handleDeepLink(
        tester.element(find.byType(MyApp)),
        uri,
      );
      await tester.pumpAndSettle();
      
      expect(find.byType(QRGenerationScreen), findsOneWidget);
    });

    // Add more test cases...
  });
}
```

---

## Test Execution Checklist

### Pre-Launch Testing

- [ ] All TC-C (Customer) test cases pass on Android
- [ ] All TC-C test cases pass on iOS
- [ ] All TC-M (Merchant) test cases pass on Android
- [ ] All TC-M test cases pass on iOS
- [ ] Universal links verified on both platforms
- [ ] Push notification deep links tested
- [ ] Error handling validated
- [ ] Analytics tracking confirmed

### Performance Testing

- [ ] Deep link opens app in < 2 seconds
- [ ] No ANR (Application Not Responding) on Android
- [ ] No crash on malformed URLs
- [ ] Memory usage stable after 100 deep link navigations

---

## Test Reporting Template

```
Test Run Date: YYYY-MM-DD
Tester: [Name]
Build Version: [X.X.X]
Device: [Device Model]
OS Version: [OS Version]

Test Results:
✅ Passed: [X/Y]
❌ Failed: [X/Y]
⚠️ Blocked: [X/Y]

Failed Tests:
- TC-XX: [Test Name] - [Reason]

Blockers:
- [Description]

Notes:
- [Any additional observations]
```

---

**Status**: ✅ DEEP LINK TEST MATRIX COMPLETE  
**Total Test Cases**: 25  
**Estimated Testing Time**: 4-6 hours (manual), 2-3 hours (automated)  
**Critical Tests**: TC-C1, TC-C2, TC-M1, TC-U1, TC-P1  
**Automation Priority**: HIGH (all critical tests should be automated)
