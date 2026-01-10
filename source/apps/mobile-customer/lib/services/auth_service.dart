import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  // NOTE: Firestore user doc is created automatically by backend onUserCreate trigger
  Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Create user account - backend onUserCreate trigger will create Firestore doc
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        
        // Wait for backend to create user doc (max 5 seconds)
        await _waitForUserDoc(credential.user!.uid, maxAttempts: 10);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Sign up error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Sign in error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Sign in with Google (web-specific implementation)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Web implementation
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Configure scopes
      googleProvider.addScope('https://www.googleapis.com/auth/userinfo.email');
      googleProvider.addScope('https://www.googleapis.com/auth/userinfo.profile');

      final credential = await _auth.signInWithPopup(googleProvider);

      // Wait for backend to create user doc if new user
      if (credential.user != null) {
        await _waitForUserDoc(credential.user!.uid, maxAttempts: 10);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Google sign in error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Sign out error: $e');
      }
      rethrow;
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Password reset error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  // Force refresh ID token to get latest custom claims
  Future<void> forceRefreshIdToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.getIdToken(true); // Force refresh
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Force refresh token error: $e');
      }
    }
  }

  // Get ID token result with custom claims
  Future<IdTokenResult?> getIdTokenResult() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await user.getIdTokenResult();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get ID token result error: $e');
      }
      return null;
    }
  }

  // Get user role from custom claims (primary source)
  Future<String?> getUserRole() async {
    try {
      final idTokenResult = await getIdTokenResult();
      if (idTokenResult != null && idTokenResult.claims != null) {
        return idTokenResult.claims!['role'] as String?;
      }
      
      // Fallback to Firestore if custom claims not available
      final profile = await getUserProfile(_auth.currentUser?.uid ?? '');
      return profile?['role'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get user role error: $e');
      }
      return null;
    }
  }

  // Get user profile from Firestore (reads from /users collection)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get user profile error: $e');
      }
      return null;
    }
  }

  // Get user profile via Cloud Function (preferred method)
  Future<Map<String, dynamic>?> getUserProfileViaCallable() async {
    try {
      final callable = _functions.httpsCallable('getUserProfile');
      final result = await callable.call();
      
      if (result.data['success'] == true) {
        return result.data['user'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get user profile via callable error: $e');
      }
      // Fallback to direct Firestore read
      if (_auth.currentUser != null) {
        return await getUserProfile(_auth.currentUser!.uid);
      }
      return null;
    }
  }

  // Ensure user doc exists in Firestore (wait for backend trigger)
  Future<bool> ensureUserDocExists(String uid, {int maxAttempts = 10}) async {
    return await _waitForUserDoc(uid, maxAttempts: maxAttempts);
  }

  // Wait for user doc to be created by backend (helper method)
  Future<bool> _waitForUserDoc(String uid, {int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          if (kDebugMode) {
            debugPrint('User doc found after ${i + 1} attempt(s)');
          }
          return true;
        }
        
        // Wait 500ms before next attempt
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Wait for user doc error: $e');
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('User doc not found after $maxAttempts attempts');
    }
    return false;
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['displayName'] = name;
      if (phone != null) updates['phoneNumber'] = phone;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update profile error: $e');
      }
      rethrow;
    }
  }

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Validate user role for customer app
  Future<bool> validateCustomerRole() async {
    try {
      final role = await getUserRole();
      return role == 'customer' || role == 'user';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Validate customer role error: $e');
      }
      return false;
    }
  }

  // Check if user account is active
  Future<bool> isUserActive() async {
    try {
      if (_auth.currentUser == null) return false;
      
      final profile = await getUserProfile(_auth.currentUser!.uid);
      return profile?['isActive'] == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Check user active error: $e');
      }
      return false;
    }
  }

  // Get error message from FirebaseAuthException
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      default:
        return 'Authentication error: ${e.message ?? 'Unknown error'}';
    }
  }

  // ===== POINTS & REDEMPTION METHODS =====
  
  /// Earn points from an offer redemption
  /// Calls Cloud Function: earnPoints
  Future<Map<String, dynamic>> earnPoints({
    required String merchantId,
    required String offerId,
    required int amount,
    required String redemptionId,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('earnPoints');
      final result = await callable.call({
        'customerId': _auth.currentUser!.uid,
        'merchantId': merchantId,
        'offerId': offerId,
        'amount': amount,
        'redemptionId': redemptionId,
      });
      
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Earn points error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Earn points error: $e');
      }
      rethrow;
    }
  }

  /// Redeem points for an offer (with QR validation)
  /// Calls Cloud Function: redeemPoints
  Future<Map<String, dynamic>> redeemPoints({
    required String offerId,
    required String qrToken,
    required String merchantId,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('redeemPoints');
      final result = await callable.call({
        'customerId': _auth.currentUser!.uid,
        'offerId': offerId,
        'qrToken': qrToken,
        'merchantId': merchantId,
      });
      
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Redeem points error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Redeem points error: $e');
      }
      rethrow;
    }
  }

  /// Get current points balance
  /// Calls Cloud Function: getBalance
  Future<Map<String, dynamic>> getPointsBalance() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('getBalance');
      final result = await callable.call({
        'customerId': _auth.currentUser!.uid,
      });
      
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Get balance error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get balance error: $e');
      }
      rethrow;
    }
  }

  /// Get points transaction history
  /// Reads directly from Firestore redemptions collection
  Future<List<Map<String, dynamic>>> getPointsHistory({int limit = 50}) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('redemptions')
          .where('customer_id', isEqualTo: _auth.currentUser!.uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get points history error: $e');
      }
      rethrow;
    }
  }

  /// Generate secure QR token for redemption
  /// Calls Cloud Function: generateSecureQRToken
  Future<Map<String, dynamic>> generateSecureQRToken({
    required String offerId,
    required String merchantId,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final callable = _functions.httpsCallable('generateSecureQRToken');
      final result = await callable.call({
        'offerId': offerId,
        'merchantId': merchantId,
        'customerId': _auth.currentUser!.uid,
      });
      
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Generate QR token error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Generate QR token error: $e');
      }
      rethrow;
    }
  }

  /// Get available offers (with optional location-based sorting)
  /// Reads directly from Firestore offers collection
  Future<List<Map<String, dynamic>>> getAvailableOffers({
    int limit = 50,
    String? category,
  }) async {
    try {
      Query query = _firestore
          .collection('offers')
          .where('status', isEqualTo: 'active')
          .where('valid_until', isGreaterThan: Timestamp.now());

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('valid_until', descending: false).limit(limit);

      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get available offers error: $e');
      }
      rethrow;
    }
  }

  /// Get error message from FirebaseFunctionsException
  String getFunctionErrorMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'You must be signed in to perform this action.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'resource-exhausted':
        return 'Too many requests. Please try again later.';
      case 'invalid-argument':
        return 'Invalid request. Please check your input.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'This resource already exists.';
      case 'aborted':
        return 'Operation was aborted. Please try again.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      default:
        return 'Error: ${e.message ?? 'Unknown error'}';
    }
  }
}
