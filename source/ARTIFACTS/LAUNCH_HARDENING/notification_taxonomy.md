# Notification Taxonomy

**Module**: C4 — Notification Intelligence (P1)  
**Purpose**: Categorize and structure push notifications for better UX  
**Technology**: Firebase Cloud Messaging (FCM)  
**Status**: Complete

---

## Overview

Define notification categories to:
1. Enable user preference controls
2. Reduce notification fatigue
3. Improve relevance and tap-through rates
4. Comply with platform best practices (Android channels, iOS categories)

---

## Customer App Notification Categories

### 1. TRANSACTIONAL (Critical)

**Purpose**: Essential updates about user actions  
**User Control**: Cannot be disabled (system-level only)  
**Frequency**: Event-driven (immediate)

**Subcategories**:

#### 1.1 Points Earned
```json
{
  "category": "transactional",
  "subcategory": "points_earned",
  "title": "Points Earned! 🎉",
  "body": "You earned 500 points at XYZ Store",
  "data": {
    "deep_link": "urbanpoints://customer/history",
    "points_amount": 500,
    "merchant_name": "XYZ Store"
  }
}
```
**Trigger**: After successful QR validation by merchant  
**Priority**: HIGH  
**Sound**: Default  
**Badge**: Update points balance

---

#### 1.2 Redemption Confirmed
```json
{
  "category": "transactional",
  "subcategory": "redemption_confirmed",
  "title": "Redemption Successful ✅",
  "body": "You redeemed '20% Off' at ABC Store",
  "data": {
    "deep_link": "urbanpoints://customer/offers/OFF_001",
    "offer_id": "OFF_001",
    "merchant_name": "ABC Store"
  }
}
```
**Trigger**: After offer redemption processed  
**Priority**: HIGH  
**Sound**: Default

---

#### 1.3 Balance Update
```json
{
  "category": "transactional",
  "subcategory": "balance_update",
  "title": "Balance Updated",
  "body": "Your balance is now 1,750 points",
  "data": {
    "deep_link": "urbanpoints://customer/history",
    "new_balance": 1750
  }
}
```
**Trigger**: After points adjustment (rare, manual admin action)  
**Priority**: MEDIUM  
**Sound**: Default

---

### 2. PROMOTIONAL (Marketing)

**Purpose**: New offers, deals, and campaigns  
**User Control**: Can be disabled  
**Frequency**: Max 2/day, 5/week

**Subcategories**:

#### 2.1 New Offer Available
```json
{
  "category": "promotional",
  "subcategory": "new_offer",
  "title": "New Offer: 30% Off! 🔥",
  "body": "Check out the latest deal from XYZ Store",
  "data": {
    "deep_link": "urbanpoints://customer/offers/OFF_002",
    "offer_id": "OFF_002",
    "merchant_name": "XYZ Store",
    "source": "push_notification"
  }
}
```
**Trigger**: Admin creates new offer  
**Priority**: DEFAULT  
**Sound**: Default  
**Frequency Cap**: 2 per day

---

#### 2.2 Limited Time Offer
```json
{
  "category": "promotional",
  "subcategory": "limited_offer",
  "title": "Hurry! Offer Expires Soon ⏰",
  "body": "20% Off expires in 24 hours",
  "data": {
    "deep_link": "urbanpoints://customer/offers/OFF_003",
    "offer_id": "OFF_003",
    "expires_at": "2025-01-05T23:59:59Z"
  }
}
```
**Trigger**: 24 hours before offer expiration  
**Priority**: DEFAULT  
**Sound**: Default

---

#### 2.3 Points Milestone
```json
{
  "category": "promotional",
  "subcategory": "points_milestone",
  "title": "Milestone Reached! 🏆",
  "body": "You've earned 5,000 points total!",
  "data": {
    "deep_link": "urbanpoints://customer/history",
    "milestone": 5000
  }
}
```
**Trigger**: User reaches point threshold (1000, 5000, 10000)  
**Priority**: LOW  
**Sound**: Custom (celebratory)

---

### 3. ENGAGEMENT (Re-activation)

**Purpose**: Re-engage inactive users  
**User Control**: Can be disabled  
**Frequency**: Max 1/week

**Subcategories**:

#### 3.1 Inactivity Reminder
```json
{
  "category": "engagement",
  "subcategory": "inactive_reminder",
  "title": "Miss You! 💙",
  "body": "Check out new offers from your favorite stores",
  "data": {
    "deep_link": "urbanpoints://customer/home",
    "source": "re_engagement"
  }
}
```
**Trigger**: 14 days since last app open  
**Priority**: LOW  
**Sound**: None (silent notification)

---

#### 3.2 Points Expiring Soon
```json
{
  "category": "engagement",
  "subcategory": "points_expiring",
  "title": "Points Expiring Soon ⚠️",
  "body": "500 points will expire in 7 days. Use them now!",
  "data": {
    "deep_link": "urbanpoints://customer/history",
    "expiring_points": 500,
    "expiry_date": "2025-01-12"
  }
}
```
**Trigger**: 7 days before points expiration (if implemented)  
**Priority**: MEDIUM  
**Sound**: Default

---

### 4. INFORMATIONAL (Updates)

**Purpose**: App updates, maintenance, announcements  
**User Control**: Cannot be disabled (but rare)  
**Frequency**: As needed (avg: 1/month)

**Subcategories**:

#### 4.1 App Update Available
```json
{
  "category": "informational",
  "subcategory": "app_update",
  "title": "Update Available",
  "body": "New features and improvements are ready",
  "data": {
    "deep_link": "https://play.google.com/store/apps/details?id=com.urbanpoints.customer",
    "version": "1.1.0"
  }
}
```
**Trigger**: New app version released  
**Priority**: DEFAULT

---

#### 4.2 System Announcement
```json
{
  "category": "informational",
  "subcategory": "system_announcement",
  "title": "Important Update",
  "body": "New merchants joining Urban Points!",
  "data": {
    "deep_link": "urbanpoints://customer/home"
  }
}
```
**Trigger**: Manual admin broadcast  
**Priority**: DEFAULT

---

## Merchant App Notification Categories

### 1. TRANSACTIONAL (Critical)

**Purpose**: Business-critical updates  
**User Control**: Cannot be disabled  
**Frequency**: Event-driven

**Subcategories**:

#### 1.1 Redemption Request
```json
{
  "category": "transactional",
  "subcategory": "redemption_request",
  "title": "New Redemption Request 🔔",
  "body": "Customer waiting at your store",
  "data": {
    "deep_link": "urbanpoints://merchant/validate",
    "customer_id": "CUST_001",
    "qr_token": "A1B2C3"
  }
}
```
**Trigger**: Customer generates QR at merchant location (geo-based)  
**Priority**: HIGH  
**Sound**: Urgent (custom)

---

#### 1.2 Offer Approved
```json
{
  "category": "transactional",
  "subcategory": "offer_approved",
  "title": "Offer Approved! ✅",
  "body": "Your offer '20% Off' is now live",
  "data": {
    "deep_link": "urbanpoints://merchant/offers/OFF_001",
    "offer_id": "OFF_001"
  }
}
```
**Trigger**: Admin approves merchant offer  
**Priority**: MEDIUM  
**Sound**: Default

---

#### 1.3 Offer Rejected
```json
{
  "category": "transactional",
  "subcategory": "offer_rejected",
  "title": "Offer Needs Revision",
  "body": "Your offer was not approved. Reason: Image quality",
  "data": {
    "deep_link": "urbanpoints://merchant/offers/OFF_002",
    "offer_id": "OFF_002",
    "rejection_reason": "Image quality too low"
  }
}
```
**Trigger**: Admin rejects merchant offer  
**Priority**: MEDIUM  
**Sound**: Default

---

### 2. ANALYTICS (Performance)

**Purpose**: Business insights and performance alerts  
**User Control**: Can be disabled  
**Frequency**: Daily/weekly summaries

**Subcategories**:

#### 2.1 Daily Summary
```json
{
  "category": "analytics",
  "subcategory": "daily_summary",
  "title": "Today's Performance 📊",
  "body": "15 redemptions, 4,200 points awarded",
  "data": {
    "deep_link": "urbanpoints://merchant/dashboard",
    "redemptions": 15,
    "points_awarded": 4200,
    "date": "2025-01-03"
  }
}
```
**Trigger**: Daily at 6 PM (configurable)  
**Priority**: LOW  
**Sound**: None

---

#### 2.2 Weekly Summary
```json
{
  "category": "analytics",
  "subcategory": "weekly_summary",
  "title": "Week in Review 📈",
  "body": "85 redemptions this week (+12% vs last week)",
  "data": {
    "deep_link": "urbanpoints://merchant/dashboard",
    "redemptions": 85,
    "growth_percent": 12
  }
}
```
**Trigger**: Monday 9 AM  
**Priority**: LOW  
**Sound**: None

---

#### 2.3 Offer Performance Alert
```json
{
  "category": "analytics",
  "subcategory": "offer_performance",
  "title": "Hot Offer! 🔥",
  "body": "Your '30% Off' was redeemed 50 times today",
  "data": {
    "deep_link": "urbanpoints://merchant/offers/OFF_003",
    "offer_id": "OFF_003",
    "redemption_count": 50
  }
}
```
**Trigger**: Offer redemptions exceed threshold  
**Priority**: LOW  
**Sound**: None

---

### 3. OPERATIONAL (System)

**Purpose**: App functionality and system updates  
**User Control**: Cannot be disabled  
**Frequency**: As needed

**Subcategories**:

#### 3.1 Compliance Alert
```json
{
  "category": "operational",
  "subcategory": "compliance_alert",
  "title": "Action Required ⚠️",
  "body": "Update business info to continue using app",
  "data": {
    "deep_link": "urbanpoints://merchant/profile",
    "required_action": "update_business_info"
  }
}
```
**Trigger**: Admin compliance check failure  
**Priority**: HIGH  
**Sound**: Urgent

---

## Notification Priority Mapping

| Category | Priority | Android Channel | iOS Interruption Level | Sound |
|----------|----------|----------------|----------------------|-------|
| Transactional | HIGH | `high_priority` | `time-sensitive` | Default |
| Promotional | DEFAULT | `marketing` | `active` | Default |
| Engagement | LOW | `engagement` | `passive` | None |
| Informational | DEFAULT | `general` | `active` | Default |
| Analytics | LOW | `analytics` | `passive` | None |
| Operational | HIGH | `system` | `time-sensitive` | Urgent |

---

## Android Notification Channels

### Customer App Channels

```dart
// Create notification channels (Android 8.0+)
void createNotificationChannels() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Transactional Channel
  const AndroidNotificationChannel transactionalChannel =
      AndroidNotificationChannel(
    'transactional',
    'Transactions',
    description: 'Important updates about your points and redemptions',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Promotional Channel
  const AndroidNotificationChannel promotionalChannel =
      AndroidNotificationChannel(
    'promotional',
    'Offers & Deals',
    description: 'New offers and promotional content',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  // Engagement Channel
  const AndroidNotificationChannel engagementChannel =
      AndroidNotificationChannel(
    'engagement',
    'Reminders',
    description: 'Reminders and re-engagement messages',
    importance: Importance.low,
    playSound: false,
  );

  // Informational Channel
  const AndroidNotificationChannel informationalChannel =
      AndroidNotificationChannel(
    'informational',
    'Updates',
    description: 'App updates and announcements',
    importance: Importance.defaultImportance,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(transactionalChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(promotionalChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(engagementChannel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(informationalChannel);
}
```

---

## iOS Notification Categories

### Customer App Categories (Info.plist)

```xml
<!-- Notification categories for iOS -->
<key>UNUserNotificationCenter</key>
<dict>
    <key>Transactional</key>
    <string>time-sensitive</string>
    <key>Promotional</key>
    <string>active</string>
    <key>Engagement</key>
    <string>passive</string>
    <key>Informational</key>
    <string>active</string>
</dict>
```

---

## Notification Frequency Caps

### Customer App Limits

| Category | Daily Cap | Weekly Cap | Monthly Cap |
|----------|-----------|------------|-------------|
| Transactional | Unlimited | Unlimited | Unlimited |
| Promotional | 2 | 5 | 15 |
| Engagement | 0 (only after 14 days inactivity) | 1 | 4 |
| Informational | 1 | 2 | 5 |

### Merchant App Limits

| Category | Daily Cap | Weekly Cap | Monthly Cap |
|----------|-----------|------------|-------------|
| Transactional | Unlimited | Unlimited | Unlimited |
| Analytics | 1 (daily summary) | 8 (daily + weekly) | 35 |
| Operational | Unlimited (rare) | Unlimited | Unlimited |

---

## Notification Payload Standard

### Standard Fields

```json
{
  "notification": {
    "title": "String",
    "body": "String",
    "image": "URL (optional)"
  },
  "data": {
    "category": "transactional|promotional|engagement|informational|analytics|operational",
    "subcategory": "specific_type",
    "deep_link": "urbanpoints://path",
    "timestamp": "ISO8601",
    "notification_id": "unique_id",
    "priority": "high|default|low",
    // Additional category-specific fields
  },
  "android": {
    "channel_id": "transactional|promotional|engagement|informational|analytics|operational",
    "priority": "high|default|low"
  },
  "apns": {
    "payload": {
      "aps": {
        "interruption-level": "time-sensitive|active|passive"
      }
    }
  }
}
```

---

## Backend Integration (Firebase Functions)

### Send Notification Function Template

```typescript
import * as admin from 'firebase-admin';

interface NotificationPayload {
  category: string;
  subcategory: string;
  title: string;
  body: string;
  deepLink: string;
  data?: Record<string, any>;
  priority?: 'high' | 'default' | 'low';
}

async function sendNotification(
  userId: string,
  payload: NotificationPayload
) {
  // Get user FCM token
  const userDoc = await admin.firestore().collection('customers').doc(userId).get();
  const fcmToken = userDoc.data()?.fcm_token;

  if (!fcmToken) {
    console.log('No FCM token for user:', userId);
    return;
  }

  // Build FCM message
  const message: admin.messaging.Message = {
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: {
      category: payload.category,
      subcategory: payload.subcategory,
      deep_link: payload.deepLink,
      timestamp: new Date().toISOString(),
      ...payload.data,
    },
    android: {
      channelId: payload.category,
      priority: payload.priority || 'default',
    },
    apns: {
      payload: {
        aps: {
          'interruption-level': payload.priority === 'high' ? 'time-sensitive' : 'active',
        },
      },
    },
    token: fcmToken,
  };

  // Send notification
  try {
    const response = await admin.messaging().send(message);
    console.log('Notification sent:', response);
    
    // Log to Firestore for tracking
    await admin.firestore().collection('notification_logs').add({
      user_id: userId,
      category: payload.category,
      subcategory: payload.subcategory,
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
      message_id: response,
    });
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}
```

---

**Status**: ✅ NOTIFICATION TAXONOMY COMPLETE  
**Total Categories**: Customer: 4, Merchant: 3  
**Total Subcategories**: Customer: 9, Merchant: 10  
**Implementation Effort**: 6-8 hours (backend functions + client handling)  
**User Experience Impact**: HIGH (reduces spam, improves relevance)
