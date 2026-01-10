import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging Service
/// Handles push notifications for Customer App
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // VAPID key for web push notifications
  // Get this from Firebase Console: Project Settings > Cloud Messaging > Web Push certificates
  static const String vapidKey = 'YOUR_VAPID_KEY_HERE';

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Request notification permissions (iOS, Web)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('FCM Permission Status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await getToken();
        if (token != null && kDebugMode) {
          debugPrint('FCM Token: $token');
        }

        // Save token to Firestore
        if (token != null) {
          await saveTokenToFirestore(token);
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(saveTokenToFirestore);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background message clicks
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else {
        if (kDebugMode) {
          debugPrint('FCM notifications permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM initialization error: $e');
      }
    }
  }

  /// Get FCM token (platform-specific)
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        // Web platform requires VAPID key
        return await _messaging.getToken(vapidKey: vapidKey);
      } else {
        // Mobile platforms
        return await _messaging.getToken();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('No authenticated user, cannot save FCM token');
        }
        return;
      }

      await _firestore.collection('user_tokens').doc(user.uid).set({
        'token': token,
        'user_id': user.uid,
        'platform': kIsWeb ? 'web' : 'mobile',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('FCM token saved to Firestore for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving FCM token: $e');
      }
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Foreground message received!');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
    }

    // You can show a custom in-app notification here
    // For example, using a SnackBar or custom dialog
  }

  /// Handle message opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Message clicked!');
      debugPrint('Data: ${message.data}');
    }

    // Navigate to specific screen based on notification data
    final notificationType = message.data['type'];
    
    switch (notificationType) {
      case 'points_earned':
        // Navigate to points history screen
        if (kDebugMode) {
          debugPrint('Navigate to points history');
        }
        break;
      case 'offer_available':
        // Navigate to offers screen
        if (kDebugMode) {
          debugPrint('Navigate to offers');
        }
        break;
      case 'tier_upgrade':
        // Navigate to profile screen
        if (kDebugMode) {
          debugPrint('Navigate to profile');
        }
        break;
      default:
        if (kDebugMode) {
          debugPrint('Unknown notification type: $notificationType');
        }
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error subscribing to topic: $e');
      }
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error unsubscribing from topic: $e');
      }
    }
  }

  /// Delete FCM token
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('user_tokens').doc(user.uid).delete();
      }
      
      if (kDebugMode) {
        debugPrint('FCM token deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting FCM token: $e');
      }
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  if (kDebugMode) {
    debugPrint('Background message received!');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
  }
}
