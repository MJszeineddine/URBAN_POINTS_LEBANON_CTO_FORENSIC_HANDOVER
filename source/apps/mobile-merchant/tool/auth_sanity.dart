/// Auth Sanity Check for Merchant App
/// Usage: dart tool/auth_sanity.dart
/// Optional env vars: TEST_EMAIL, TEST_PASSWORD for sign-in testing

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart';

void main() async {
  print('========================================');
  print('🧪 DAY 2 AUTH SANITY CHECK - MERCHANT APP');
  print('========================================\n');

  // Step 1: Firebase Initialization
  print('📱 Step 1: Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    print('   Project: ${DefaultFirebaseOptions.currentPlatform.projectId}');
  } catch (e) {
    print('❌ FAIL: Firebase initialization failed: $e');
    exit(1);
  }

  // Step 2: Check Current User
  print('\n📱 Step 2: Checking current user...');
  final auth = FirebaseAuth.instance;
  final currentUser = auth.currentUser;
  
  if (currentUser == null) {
    print('ℹ️  No user currently signed in');
  } else {
    print('✅ User signed in:');
    print('   UID: ${currentUser.uid}');
    print('   Email: ${currentUser.email}');
    print('   Email Verified: ${currentUser.emailVerified}');
  }

  // Step 3: Test Sign-In (if credentials provided)
  final testEmail = Platform.environment['TEST_EMAIL'];
  final testPassword = Platform.environment['TEST_PASSWORD'];
  
  if (testEmail != null && testPassword != null) {
    print('\n📱 Step 3: Testing sign-in with provided credentials...');
    try {
      // Sign out first if already signed in
      if (currentUser != null) {
        await auth.signOut();
        print('   Signed out previous user');
      }

      // Sign in
      final userCredential = await auth.signInWithEmailAndPassword(
        email: testEmail,
        password: testPassword,
      );
      final user = userCredential.user!;
      print('✅ Sign-in successful');
      print('   UID: ${user.uid}');
      print('   Email: ${user.email}');

      // Step 4: Get ID Token and Custom Claims
      print('\n📱 Step 4: Fetching ID token and custom claims...');
      final idTokenResult = await user.getIdTokenResult(true); // Force refresh
      final claims = idTokenResult.claims ?? {};
      final role = claims['role'] as String?;
      
      print('✅ ID token retrieved');
      print('   Token expires: ${idTokenResult.expirationTime}');
      print('   Custom claims role: ${role ?? "NOT SET"}');

      // Step 5: Check Firestore User Document
      print('\n📱 Step 5: Checking Firestore user document...');
      final db = FirebaseFirestore.instance;
      
      try {
        final userDoc = await db.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          print('❌ FAIL: User document does not exist in Firestore /users/${user.uid}');
          print('   Expected: Document created by onUserCreate trigger');
          exit(1);
        }
        
        final userData = userDoc.data()!;
        final firestoreRole = userData['role'] as String?;
        final isActive = userData['isActive'] as bool? ?? false;
        
        print('✅ User document found');
        print('   Firestore role: ${firestoreRole ?? "NOT SET"}');
        print('   isActive: $isActive');
        print('   email: ${userData['email']}');
        print('   pointsBalance: ${userData['pointsBalance']}');

        // Step 6: Role Validation
        print('\n📱 Step 6: Validating role for Merchant app...');
        final validRole = 'merchant';
        final effectiveRole = role ?? firestoreRole;
        
        if (effectiveRole == null) {
          print('❌ FAIL: No role found in custom claims or Firestore');
          exit(1);
        }
        
        if (effectiveRole != validRole) {
          print('❌ FAIL: Invalid role for Merchant app');
          print('   Expected: merchant');
          print('   Got: $effectiveRole');
          exit(1);
        }
        
        if (!isActive) {
          print('❌ FAIL: User is not active (isActive: false)');
          exit(1);
        }
        
        print('✅ Role validation PASSED');
        print('   Role: $effectiveRole');
        print('   isActive: $isActive');

        // Final Result
        print('\n========================================');
        print('✅ ✅ ✅ ALL CHECKS PASSED ✅ ✅ ✅');
        print('========================================');
        print('Summary:');
        print('  • Firebase: ✅ Initialized');
        print('  • Auth: ✅ Signed in (${user.email})');
        print('  • Claims: ✅ Role = $effectiveRole');
        print('  • Firestore: ✅ User doc exists');
        print('  • Role check: ✅ Valid for Merchant app');
        print('  • isActive: ✅ true');
        print('========================================\n');
        
      } catch (e) {
        print('❌ FAIL: Error accessing Firestore: $e');
        exit(1);
      }

      // Clean up
      await auth.signOut();
      
    } catch (e) {
      print('❌ FAIL: Sign-in failed: $e');
      exit(1);
    }
  } else {
    print('\n📱 Step 3: Skipping sign-in test (no credentials provided)');
    print('   Set TEST_EMAIL and TEST_PASSWORD env vars to enable');
    print('\n========================================');
    print('⚠️  PARTIAL CHECK COMPLETE');
    print('========================================');
    print('Summary:');
    print('  • Firebase: ✅ Initialized');
    print('  • Auth: ℹ️  ${currentUser != null ? "User signed in" : "No user"}');
    print('  • E2E test: ⏭️  SKIPPED (no credentials)');
    print('========================================\n');
  }

  exit(0);
}
