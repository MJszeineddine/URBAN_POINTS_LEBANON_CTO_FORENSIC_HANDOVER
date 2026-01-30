/**
 * Urban Points Lebanon - Authentication Functions
 * Day 1 Integration: Firebase Auth → Cloud Functions → Firestore → Mobile Apps
 * 
 * Functions:
 * 1. onUserCreate - Auto-create Firestore user document when Firebase Auth user is created
 * 2. setCustomClaims - Assign role-based custom claims (customer/merchant/admin)
 * 3. verifyEmailComplete - Mark user as email-verified in Firestore
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Logger from './logger';

const db = admin.firestore();

/**
 * Automatically create Firestore user document when Firebase Auth user is created
 * Triggered by: Firebase Auth user creation
 * Creates: /users/{uid} document with default fields
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    Logger.info('Creating user document', { userId: user.uid, email: user.email });

    // Determine default role based on email pattern
    let defaultRole: 'customer' | 'merchant' | 'admin' = 'customer';
    
    if (user.email) {
      if (user.email.includes('+merchant') || user.email.includes('@merchant')) {
        defaultRole = 'merchant';
      } else if (user.email.includes('+admin') || user.email.includes('@admin')) {
        defaultRole = 'admin';
      }
    }

    // Create user document in Firestore
    const userData = {
      uid: user.uid,
      email: user.email || null,
      displayName: user.displayName || null,
      phoneNumber: user.phoneNumber || null,
      photoURL: user.photoURL || null,
      role: defaultRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      pointsBalance: 0,
      isActive: true,
      emailVerified: user.emailVerified || false,
      metadata: {
        creationTime: user.metadata.creationTime,
        lastSignInTime: user.metadata.lastSignInTime,
      },
    };

    await db.collection('users').doc(user.uid).set(userData);

    // Set initial custom claims
    await admin.auth().setCustomUserClaims(user.uid, {
      role: defaultRole,
    });

    Logger.info('User document created successfully', {
      userId: user.uid,
      role: defaultRole,
    });

    return {
      success: true,
      userId: user.uid,
      role: defaultRole,
    };

  } catch (error) {
    Logger.error('Error creating user document', error as Error, {
      userId: user.uid,
    });
    throw error;
  }
});

/**
 * Set custom claims for role-based access control
 * Callable function - requires admin role
 * @param data - { userId: string, role: 'customer' | 'merchant' | 'admin' }
 */
export const setCustomClaims = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to set custom claims'
      );
    }

    // Verify caller is admin
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const callerData = callerDoc.data();

    if (!callerData || callerData.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can set custom claims'
      );
    }

    // Validate input
    const { userId, role } = data;
    if (!userId || !role) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'userId and role are required'
      );
    }

    if (!['customer', 'merchant', 'admin'].includes(role)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'role must be customer, merchant, or admin'
      );
    }

    // Set custom claims
    await admin.auth().setCustomUserClaims(userId, { role });

    // Update Firestore user document
    await db.collection('users').doc(userId).update({
      role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    Logger.info('Custom claims set successfully', {
      userId,
      role,
      setBy: context.auth.uid,
    });

    return {
      success: true,
      userId,
      role,
    };

  } catch (error) {
    Logger.error('Error setting custom claims', error as Error, {
      userId: data?.userId,
    });
    throw error;
  }
});

/**
 * Mark user as email-verified in Firestore
 * Callable function - requires authentication
 * Verifies that Firebase Auth email is verified before updating Firestore
 */
export const verifyEmailComplete = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to verify email'
      );
    }

    const userId = context.auth.uid;

    // Get latest user data from Firebase Auth
    const user = await admin.auth().getUser(userId);

    if (!user.emailVerified) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Email is not verified in Firebase Auth. Please verify your email first.'
      );
    }

    // Update Firestore user document
    await db.collection('users').doc(userId).update({
      emailVerified: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    Logger.info('Email verification updated in Firestore', { userId });

    return {
      success: true,
      userId,
      emailVerified: true,
    };

  } catch (error) {
    Logger.error('Error updating email verification', error as Error, {
      userId: context.auth?.uid,
    });
    throw error;
  }
});

/**
 * Get current user profile with custom claims
 * Callable function - requires authentication
 * Returns: User data from Firestore + custom claims from Auth token
 */
export const getUserProfile = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated to get user profile'
      );
    }

    const userId = context.auth.uid;

    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User document not found in Firestore'
      );
    }

    const userData = userDoc.data();

    // Get custom claims from token
    const customClaims = context.auth.token;

    Logger.info('User profile retrieved', { userId });

    return {
      success: true,
      user: {
        ...userData,
        customClaims: {
          role: customClaims.role || userData?.role || 'customer',
        },
      },
    };

  } catch (error) {
    Logger.error('Error getting user profile', error as Error, {
      userId: context.auth?.uid,
    });
    throw error;
  }
});
