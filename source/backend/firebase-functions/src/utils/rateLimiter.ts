/**
 * Rate Limiting for Cloud Functions
 * Simple Firestore-based rate limiter
 */

import * as admin from 'firebase-admin';

// Ensure Firebase app is initialized before using Firestore in utility modules
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface RateLimitConfig {
  maxRequests: number;
  windowMs: number; // Time window in milliseconds
}

const DEFAULT_CONFIG: RateLimitConfig = {
  maxRequests: 100,
  windowMs: 60000, // 1 minute
};

/**
 * Check if user has exceeded rate limit
 * @param userId - User ID to check
 * @param operation - Operation name (e.g., 'earnPoints')
 * @param config - Rate limit configuration
 * @returns true if rate limit exceeded
 */
export async function isRateLimited(
  userId: string,
  operation: string,
  config: RateLimitConfig = DEFAULT_CONFIG
): Promise<boolean> {
  try {
    const now = Date.now();
    const windowStart = now - config.windowMs;
    
    const rateLimitRef = db.collection('rate_limits').doc(`${userId}_${operation}`);
    const doc = await rateLimitRef.get();
    
    if (!doc.exists) {
      // First request in window
      await rateLimitRef.set({
        count: 1,
        windowStart: admin.firestore.Timestamp.fromMillis(now),
        lastRequest: admin.firestore.Timestamp.fromMillis(now),
      });
      return false;
    }
    
    const data = doc.data()!;
    const windowStartTime = data.windowStart.toMillis();
    
    if (windowStartTime < windowStart) {
      // Window expired, reset counter
      await rateLimitRef.set({
        count: 1,
        windowStart: admin.firestore.Timestamp.fromMillis(now),
        lastRequest: admin.firestore.Timestamp.fromMillis(now),
      });
      return false;
    }
    
    // Check if limit exceeded
    if (data.count >= config.maxRequests) {
      return true;
    }
    
    // Increment counter
    await rateLimitRef.update({
      count: admin.firestore.FieldValue.increment(1),
      lastRequest: admin.firestore.Timestamp.fromMillis(now),
    });
    
    return false;
  } catch (error) {
    console.error('Rate limit check failed:', error);
    // Fail open - don't block on rate limit errors
    return false;
  }
}

/**
 * Rate limit configurations for different operations
 */
export const RATE_LIMITS = {
  earnPoints: { maxRequests: 50, windowMs: 60000 }, // 50/min
  redeemPoints: { maxRequests: 30, windowMs: 60000 }, // 30/min
  createOffer: { maxRequests: 20, windowMs: 60000 }, // 20/min
  initiatePayment: { maxRequests: 10, windowMs: 60000 }, // 10/min
};
