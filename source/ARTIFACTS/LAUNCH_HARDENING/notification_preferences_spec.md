# Notification Preferences Specification

**Module**: C4 — Notification Intelligence  
**Purpose**: User-controlled notification settings  
**Technology**: Firebase Firestore + FCM Topics  
**Status**: Complete

---

## Overview

Enable users to customize notification preferences to:
1. Reduce unwanted notifications
2. Increase user satisfaction
3. Comply with best practices (user control)
4. Maintain engagement without annoyance

---

## Preference Data Model

### Customer Preferences (Firestore)

**Collection**: `customers/{userId}`  
**Field**: `notification_preferences`

```typescript
interface NotificationPreferences {
  // Category toggles
  transactional: boolean;          // Always true (cannot disable)
  promotional: boolean;            // Default: true
  engagement: boolean;             // Default: true
  informational: boolean;          // Default: true
  
  // Subcategory toggles (optional granular control)
  subcategories: {
    points_earned: boolean;        // Default: true (transactional)
    redemption_confirmed: boolean; // Default: true (transactional)
    new_offer: boolean;            // Default: true (promotional)
    limited_offer: boolean;        // Default: true (promotional)
    points_milestone: boolean;     // Default: false (promotional, optional)
    inactive_reminder: boolean;    // Default: true (engagement)
    points_expiring: boolean;      // Default: true (engagement)
  };
  
  // Time preferences
  quiet_hours: {
    enabled: boolean;              // Default: false
    start_time: string;            // "22:00" (10 PM)
    end_time: string;              // "08:00" (8 AM)
  };
  
  // Frequency preferences
  max_daily_promotional: number;   // Default: 2 (1-5 range)
  
  // FCM token
  fcm_token: string | null;
  fcm_token_updated_at: Timestamp;
}
```

**Default Preferences**:
```json
{
  "transactional": true,
  "promotional": true,
  "engagement": true,
  "informational": true,
  "subcategories": {
    "points_earned": true,
    "redemption_confirmed": true,
    "new_offer": true,
    "limited_offer": true,
    "points_milestone": false,
    "inactive_reminder": true,
    "points_expiring": true
  },
  "quiet_hours": {
    "enabled": false,
    "start_time": "22:00",
    "end_time": "08:00"
  },
  "max_daily_promotional": 2,
  "fcm_token": null,
  "fcm_token_updated_at": null
}
```

---

### Merchant Preferences (Firestore)

**Collection**: `merchants/{merchantId}`  
**Field**: `notification_preferences`

```typescript
interface MerchantNotificationPreferences {
  // Category toggles
  transactional: boolean;          // Always true (cannot disable)
  analytics: boolean;              // Default: true
  operational: boolean;            // Always true (cannot disable)
  
  // Subcategory toggles
  subcategories: {
    redemption_request: boolean;   // Default: true (transactional)
    offer_approved: boolean;       // Default: true (transactional)
    offer_rejected: boolean;       // Default: true (transactional)
    daily_summary: boolean;        // Default: true (analytics)
    weekly_summary: boolean;       // Default: true (analytics)
    offer_performance: boolean;    // Default: false (analytics, optional)
  };
  
  // Time preferences
  daily_summary_time: string;      // Default: "18:00" (6 PM)
  weekly_summary_day: string;      // Default: "monday" (day of week)
  quiet_hours: {
    enabled: boolean;              // Default: false
    start_time: string;            // "22:00"
    end_time: string;              // "08:00"
  };
  
  // FCM token
  fcm_token: string | null;
  fcm_token_updated_at: Timestamp;
}
```

---

## Settings UI Specification

### Customer App Settings Screen

```
┌─────────────────────────────────────────┐
│ ← Notification Settings                 │
├─────────────────────────────────────────┤
│                                         │
│ CATEGORY PREFERENCES                    │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Points & Transactions      [ON] │    │
│ │ Cannot be disabled              │    │
│ └─────────────────────────────────┘    │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Offers & Deals             [ON] │    │
│ │ New offers and promotions       │    │
│ └─────────────────────────────────┘    │
│   • New Offer Alerts         [ON]      │
│   • Limited Time Offers      [ON]      │
│   • Points Milestones        [OFF]     │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Reminders                  [ON] │    │
│ │ Re-engagement notifications     │    │
│ └─────────────────────────────────┘    │
│   • Inactivity Reminders     [ON]      │
│   • Points Expiring Alerts   [ON]      │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ App Updates                [ON] │    │
│ │ System announcements            │    │
│ └─────────────────────────────────┘    │
│                                         │
│ ADVANCED SETTINGS                       │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Quiet Hours               [OFF] │    │
│ │ Pause notifications             │    │
│ └─────────────────────────────────┘    │
│   From: 10:00 PM    To: 8:00 AM        │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Daily Offer Limit                │   │
│ │ Max promotional per day: [2]     │   │
│ │ ───●────────                     │   │
│ │ 1         5                      │   │
│ └─────────────────────────────────┘    │
│                                         │
│ ┌───────────────────────────┐          │
│ │ Test Notifications        │          │
│ └───────────────────────────┘          │
│                                         │
└─────────────────────────────────────────┘
```

---

### Merchant App Settings Screen

```
┌─────────────────────────────────────────┐
│ ← Notification Settings                 │
├─────────────────────────────────────────┤
│                                         │
│ BUSINESS NOTIFICATIONS                  │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Redemptions & Offers      [ON] │    │
│ │ Cannot be disabled              │    │
│ └─────────────────────────────────┘    │
│   • Redemption Requests      [ON]      │
│   • Offer Approvals          [ON]      │
│   • Offer Rejections         [ON]      │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Performance Reports        [ON] │    │
│ │ Daily & weekly summaries        │    │
│ └─────────────────────────────────┘    │
│   • Daily Summary            [ON]      │
│     Sent at: [ 6:00 PM ▼]              │
│   • Weekly Summary           [ON]      │
│     Sent on: [ Monday ▼]               │
│   • Performance Alerts       [OFF]     │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ System Alerts             [ON] │    │
│ │ Cannot be disabled              │    │
│ └─────────────────────────────────┘    │
│                                         │
│ QUIET HOURS                             │
│                                         │
│ ┌─────────────────────────────────┐    │
│ │ Quiet Hours               [OFF] │    │
│ │ Pause non-urgent alerts         │    │
│ └─────────────────────────────────┘    │
│   From: 10:00 PM    To: 8:00 AM        │
│                                         │
└─────────────────────────────────────────┘
```

---

## Settings UI Implementation

### Customer Settings Screen Widget

```dart
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _promotional = true;
  bool _engagement = true;
  bool _informational = true;
  
  // Subcategories
  bool _newOffers = true;
  bool _limitedOffers = true;
  bool _milestones = false;
  bool _inactiveReminders = true;
  bool _pointsExpiring = true;
  
  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);
  
  // Frequency
  int _maxDailyPromotional = 2;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final prefs = doc.data()?['notification_preferences'];
      if (prefs != null) {
        setState(() {
          _promotional = prefs['promotional'] ?? true;
          _engagement = prefs['engagement'] ?? true;
          _informational = prefs['informational'] ?? true;
          
          final subs = prefs['subcategories'] ?? {};
          _newOffers = subs['new_offer'] ?? true;
          _limitedOffers = subs['limited_offer'] ?? true;
          _milestones = subs['points_milestone'] ?? false;
          _inactiveReminders = subs['inactive_reminder'] ?? true;
          _pointsExpiring = subs['points_expiring'] ?? true;
          
          final quietHours = prefs['quiet_hours'] ?? {};
          _quietHoursEnabled = quietHours['enabled'] ?? false;
          
          _maxDailyPromotional = prefs['max_daily_promotional'] ?? 2;
          
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .update({
      'notification_preferences': {
        'transactional': true, // Always enabled
        'promotional': _promotional,
        'engagement': _engagement,
        'informational': _informational,
        'subcategories': {
          'points_earned': true,
          'redemption_confirmed': true,
          'new_offer': _newOffers,
          'limited_offer': _limitedOffers,
          'points_milestone': _milestones,
          'inactive_reminder': _inactiveReminders,
          'points_expiring': _pointsExpiring,
        },
        'quiet_hours': {
          'enabled': _quietHoursEnabled,
          'start_time': '${_quietStart.hour}:${_quietStart.minute.toString().padLeft(2, '0')}',
          'end_time': '${_quietEnd.hour}:${_quietEnd.minute.toString().padLeft(2, '0')}',
        },
        'max_daily_promotional': _maxDailyPromotional,
      },
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton(
            onPressed: _savePreferences,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'CATEGORY PREFERENCES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // Transactional (Always On)
          _buildCategoryTile(
            title: 'Points & Transactions',
            subtitle: 'Cannot be disabled',
            value: true,
            onChanged: null, // Cannot toggle
          ),

          // Promotional
          _buildCategoryTile(
            title: 'Offers & Deals',
            subtitle: 'New offers and promotions',
            value: _promotional,
            onChanged: (value) => setState(() => _promotional = value),
          ),
          if (_promotional) ...[
            _buildSubcategoryTile(
              title: 'New Offer Alerts',
              value: _newOffers,
              onChanged: (value) => setState(() => _newOffers = value),
            ),
            _buildSubcategoryTile(
              title: 'Limited Time Offers',
              value: _limitedOffers,
              onChanged: (value) => setState(() => _limitedOffers = value),
            ),
            _buildSubcategoryTile(
              title: 'Points Milestones',
              value: _milestones,
              onChanged: (value) => setState(() => _milestones = value),
            ),
          ],

          // Engagement
          _buildCategoryTile(
            title: 'Reminders',
            subtitle: 'Re-engagement notifications',
            value: _engagement,
            onChanged: (value) => setState(() => _engagement = value),
          ),
          if (_engagement) ...[
            _buildSubcategoryTile(
              title: 'Inactivity Reminders',
              value: _inactiveReminders,
              onChanged: (value) => setState(() => _inactiveReminders = value),
            ),
            _buildSubcategoryTile(
              title: 'Points Expiring Alerts',
              value: _pointsExpiring,
              onChanged: (value) => setState(() => _pointsExpiring = value),
            ),
          ],

          // Informational
          _buildCategoryTile(
            title: 'App Updates',
            subtitle: 'System announcements',
            value: _informational,
            onChanged: (value) => setState(() => _informational = value),
          ),

          const Divider(height: 32),

          // Quiet Hours
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'ADVANCED SETTINGS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          SwitchListTile(
            title: const Text('Quiet Hours'),
            subtitle: const Text('Pause notifications'),
            value: _quietHoursEnabled,
            onChanged: (value) => setState(() => _quietHoursEnabled = value),
          ),

          if (_quietHoursEnabled) ...[
            ListTile(
              title: const Text('From'),
              trailing: TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _quietStart,
                  );
                  if (time != null) {
                    setState(() => _quietStart = time);
                  }
                },
                child: Text(_quietStart.format(context)),
              ),
            ),
            ListTile(
              title: const Text('To'),
              trailing: TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _quietEnd,
                  );
                  if (time != null) {
                    setState(() => _quietEnd = time);
                  }
                },
                child: Text(_quietEnd.format(context)),
              ),
            ),
          ],

          // Daily Limit
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Offer Limit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text('Max promotional per day: $_maxDailyPromotional'),
                Slider(
                  value: _maxDailyPromotional.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _maxDailyPromotional.toString(),
                  onChanged: (value) {
                    setState(() => _maxDailyPromotional = value.toInt());
                  },
                ),
              ],
            ),
          ),

          // Test Notification
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _sendTestNotification,
              child: const Text('Test Notifications'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSubcategoryTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: onChanged,
        dense: true,
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    // Call Cloud Function to send test notification
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('sendTestNotification').call({
        'user_id': user.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

---

## Backend Preference Validation

### Cloud Function: Check User Preferences Before Sending

```typescript
async function shouldSendNotification(
  userId: string,
  category: string,
  subcategory: string
): Promise<boolean> {
  // Get user preferences
  const userDoc = await admin.firestore().collection('customers').doc(userId).get();
  const prefs = userDoc.data()?.notification_preferences;

  if (!prefs) {
    return true; // Default: allow all
  }

  // Check category preference
  if (prefs[category] === false) {
    return false;
  }

  // Check subcategory preference
  if (prefs.subcategories && prefs.subcategories[subcategory] === false) {
    return false;
  }

  // Check quiet hours
  if (prefs.quiet_hours?.enabled) {
    const now = new Date();
    const currentTime = `${now.getHours()}:${now.getMinutes().toString().padStart(2, '0')}`;
    
    if (isInQuietHours(currentTime, prefs.quiet_hours.start_time, prefs.quiet_hours.end_time)) {
      // Allow transactional, block others
      if (category !== 'transactional') {
        return false;
      }
    }
  }

  // Check daily promotional limit
  if (category === 'promotional') {
    const today = new Date().toISOString().split('T')[0];
    const sentToday = await admin.firestore()
      .collection('notification_logs')
      .where('user_id', '==', userId)
      .where('category', '==', 'promotional')
      .where('sent_at', '>=', admin.firestore.Timestamp.fromDate(new Date(today)))
      .count()
      .get();

    const maxDaily = prefs.max_daily_promotional || 2;
    if (sentToday.data().count >= maxDaily) {
      return false; // Exceeded daily limit
    }
  }

  return true;
}

function isInQuietHours(currentTime: string, startTime: string, endTime: string): boolean {
  // Simple time comparison (assumes 24-hour format)
  return currentTime >= startTime || currentTime <= endTime;
}
```

---

## FCM Topics for Category Management

### Subscribe Users to Topics

```dart
Future<void> updateFCMTopics(NotificationPreferences prefs) async {
  final messaging = FirebaseMessaging.instance;

  // Subscribe/unsubscribe based on preferences
  if (prefs.promotional) {
    await messaging.subscribeToTopic('promotional');
  } else {
    await messaging.unsubscribeFromTopic('promotional');
  }

  if (prefs.engagement) {
    await messaging.subscribeToTopic('engagement');
  } else {
    await messaging.unsubscribeFromTopic('engagement');
  }

  if (prefs.informational) {
    await messaging.subscribeToTopic('informational');
  } else {
    await messaging.unsubscribeFromTopic('informational');
  }

  // Transactional always subscribed (use user-specific targeting)
}
```

---

## Summary

| Feature | Customer App | Merchant App | Implementation Effort |
|---------|-------------|--------------|---------------------|
| Category Toggles | 4 categories | 3 categories | 2 hours |
| Subcategory Toggles | 7 subcategories | 6 subcategories | 2 hours |
| Quiet Hours | ✅ Yes | ✅ Yes | 2 hours |
| Frequency Caps | ✅ Daily limit slider | ✅ Summary time pickers | 3 hours |
| FCM Topics | ✅ Yes | ✅ Yes | 1 hour |
| Backend Validation | ✅ Yes | ✅ Yes | 4 hours |
| **Total Effort** | | | **14 hours** |

---

**Status**: ✅ NOTIFICATION PREFERENCES SPECIFICATION COMPLETE  
**User Experience Impact**: HIGH (empowers users, reduces churn)  
**Implementation Priority**: P1 (post-launch enhancement)  
**Risk Level**: LOW (purely additive feature)
