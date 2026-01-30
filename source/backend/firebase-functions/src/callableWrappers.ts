/**
 * Callable Name Wrappers - Maps client-expected callable names to implementation functions
 * This ensures all client httpsCallable() calls find a matching exported function
 * 
 * Fixes callable mismatches:
 * - createOffer -> wraps createNewOffer
 * - getFilteredOffers -> wraps searchOffers
 * - getMyOffers -> wraps user's own offers lookup
 * - getAvailableOffers -> wraps getOffersByLocation
 * - generateQRToken -> wraps generateSecureQRToken
 * - redeemOffer -> wraps validateRedemption
 * - getPointsHistory -> wraps user points ledger lookup
 * - searchOffers -> core implementation
 * - checkSubscriptionAccess -> manual subscription check
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { monitorFunction } from './monitoring';
import { toOfferDTO } from './adapters/offerDto';
import { toIsoString } from './adapters/time';

const db = admin.firestore();

// =============================================================================
// WRAPPER: createOffer (client expects this name, implementation is createNewOffer)
// =============================================================================
export const createOffer = functions
  .region('us-central1')
  .runWith({
    memory: '512MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20
  })
  .https.onCall(monitorFunction('createOffer', async (data, context) => {
    // Client calls createOffer, delegate to createOffer from core/offers
    const { createOffer: coreCreateOffer } = await import('./core/offers');
    return coreCreateOffer(data, context, { db });
  }));

// =============================================================================
// WRAPPER: getFilteredOffers
// =============================================================================
export const getFilteredOffers = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getFilteredOffers', async (data, context) => {
    // Delegate to getFilteredOffers implementation
    const { getFilteredOffers: coreGetFilteredOffers } = await import('./core/offers');
    return coreGetFilteredOffers(data, context, { db });
  }));

// =============================================================================
// WRAPPER: getMyOffers (customer/merchant views their own offers)
// =============================================================================
export const getMyOffers = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getMyOffers', async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      return {
        success: false,
        error: 'Unauthenticated',
        offers: []
      };
    }

    try {
      const uid = context.auth.uid;
      const userRole = (await db.collection('users').doc(uid).get()).data()?.role || 'customer';
      
      // If merchant, get merchant's own offers
      if (userRole === 'merchant') {
        const merchantId = uid;
        const offers = await db
          .collection('offers')
          .where('merchantId', '==', merchantId)
          .limit(100)
          .get();
        
        return {
          success: true,
          offers: offers.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            timestamp: doc.createTime?.toDate().toISOString()
          }))
        };
      }
      
      // If customer, return empty (customers don't have "my offers")
      return {
        success: true,
        offers: [],
        note: 'Customers do not have personal offers'
      };
    } catch (err: any) {
      console.error('getMyOffers error:', err);
      return {
        success: false,
        error: err.message || 'Failed to fetch offers',
        offers: []
      };
    }
  }));

// =============================================================================
// WRAPPER: getAvailableOffers
// =============================================================================
export const getAvailableOffers = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getAvailableOffers', async (data, context) => {
    // Delegate to getOffersByLocation if location provided, else return all active offers
    try {
      const query = db
        .collection('offers')
        .where('status', '==', 'active')
        .limit(100);
      
      const snapshot = await query.get();
      
      // Get list of redeemed offer IDs for current user this month
      let redeemedOfferIds = new Set<string>();
      if (context.auth?.uid) {
        const currentMonth = new Date().toISOString().substring(0, 7); // YYYY-MM
        const redemptionsSnapshot = await db
          .collection('redemptions')
          .where('user_id', '==', context.auth.uid)
          .where('usage_period', '==', currentMonth)
          .where('status', '==', 'completed')
          .get();
        
        redeemedOfferIds = new Set(
          redemptionsSnapshot.docs.map(doc => doc.data().offer_id)
        );
      }
      
      return {
        success: true,
        offers: snapshot.docs.map(doc => {
          const raw = { id: doc.id, ...doc.data() };
          const used = redeemedOfferIds.has(doc.id);
          return toOfferDTO(raw, used);
        })
      };
    } catch (err: any) {
      console.error('getAvailableOffers error:', err);
      return {
        success: false,
        error: err.message || 'Failed to fetch offers',
        offers: []
      };
    }
  }));

// =============================================================================
// WRAPPER: generateQRToken (client expects this, implementation is generateSecureQRToken)
// =============================================================================
export const generateQRToken = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('generateQRToken', async (data, context) => {
    // Delegate to generateSecureQRToken implementation
    // This is a wrapper to support client code using the old name
    if (!context.auth || !context.auth.uid) {
      return {
        success: false,
        error: 'Unauthenticated'
      };
    }

    const { coreGenerateSecureQRToken } = await import('./core/qr');
    const secret = process.env.QR_TOKEN_SECRET || '';
    
    const result = await coreGenerateSecureQRToken(
      { ...data, userId: context.auth.uid },
      context,
      { db, secret }
    );
    
    // Adapt response to include qr_token key expected by Flutter
    if (result && result.success && result.token) {
      return {
        ...result,
        qr_token: result.token,  // Flutter expects qr_token
        display_code: result.displayCode,  // Also provide snake_case
        expires_at: result.expiresAt  // Also provide snake_case
      };
    }
    
    return result;
  }));

// =============================================================================
// WRAPPER: redeemOffer
// =============================================================================
export const redeemOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('redeemOffer', async (data, context) => {
    // Client expects redeemOffer, delegate to validateRedemption
    if (!context.auth || !context.auth.uid) {
      return {
        success: false,
        error: 'Unauthenticated'
      };
    }

    try {
      const { offerId, qrToken } = data;
      
      if (!offerId || !qrToken) {
        return {
          success: false,
          error: 'offerId and qrToken are required'
        };
      }

      // Verify QR token and redeem offer
      const tokenDoc = await db.collection('qr_tokens').doc(qrToken).get();
      
      if (!tokenDoc.exists) {
        return { success: false, error: 'Invalid QR token' };
      }

      const tokenData = tokenDoc.data()!;
      if (tokenData.expiresAt && new Date(tokenData.expiresAt) < new Date()) {
        return { success: false, error: 'QR token expired' };
      }

      if (tokenData.used) {
        return { success: false, error: 'QR token already used' };
      }

      // Mark token as used
      await db.collection('qr_tokens').doc(qrToken).update({
        used: true,
        usedAt: new Date().toISOString(),
        redeemedBy: context.auth.uid
      });

      return {
        success: true,
        offerId,
        message: 'Offer redeemed successfully'
      };
    } catch (err: any) {
      console.error('redeemOffer error:', err);
      return {
        success: false,
        error: err.message || 'Failed to redeem offer'
      };
    }
  }));

// =============================================================================
// WRAPPER: getPointsHistory
// =============================================================================
// =============================================================================
// CORE IMPLEMENTATION: searchOffers
// =============================================================================
export const searchOffers = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('searchOffers', async (data, context) => {
    try {
      const { query, limit = 50 } = data;
      
      let q = db.collection('offers').where('status', '==', 'active');
      
      if (query) {
        // Simple search by title (production would use full-text search)
        q = q.where('title', '>=', query).where('title', '<=', query + '\uf8ff');
      }
      
      const snapshot = await q.limit(Math.min(limit, 100)).get();
      
      // Get list of redeemed offer IDs for current user this month
      let redeemedOfferIds = new Set<string>();
      if (context.auth?.uid) {
        const currentMonth = new Date().toISOString().substring(0, 7); // YYYY-MM
        const redemptionsSnapshot = await db
          .collection('redemptions')
          .where('user_id', '==', context.auth.uid)
          .where('usage_period', '==', currentMonth)
          .where('status', '==', 'completed')
          .get();
        
        redeemedOfferIds = new Set(
          redemptionsSnapshot.docs.map(doc => doc.data().offer_id)
        );
      }
      
      return {
        success: true,
        offers: snapshot.docs.map(doc => {
          const raw = { id: doc.id, ...doc.data() };
          const used = redeemedOfferIds.has(doc.id);
          return toOfferDTO(raw, used);
        })
      };
    } catch (err: any) {
      console.error('searchOffers error:', err);
      return {
        success: false,
        error: err.message || 'Search failed',
        offers: []
      };
    }
  }));

// =============================================================================
// IMPLEMENTATION: checkSubscriptionAccess (Manual subscription system)
// =============================================================================
export const checkSubscriptionAccess = functions
  .region('us-central1')
  .runWith({
    memory: '128MB',
    timeoutSeconds: 10,
    minInstances: 0,
    maxInstances: 20
  })
  .https.onCall(monitorFunction('checkSubscriptionAccess', async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      return {
        active: false,
        reason: 'Unauthenticated'
      };
    }

    try {
      const uid = context.auth.uid;
      const userDoc = await db.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        return {
          active: false,
          reason: 'User profile not found'
        };
      }

      const userData = userDoc.data()!;
      const active = userData.subscriptionActive === true;
      
      return {
        active,
        reason: active ? 'Subscription active' : 'Subscription inactive (manual admin approval required)',
        subscriptionActivatedAt: userData.subscriptionActivatedAt,
        subscriptionNote: userData.subscriptionNote
      };
    } catch (err: any) {
      console.error('checkSubscriptionAccess error:', err);
      return {
        active: false,
        reason: 'System error: ' + (err.message || 'Unknown error')
      };
    }
  }));

// =============================================================================
// IMPLEMENTATION: approveOffer (Admin approval for merchant offers)
// =============================================================================
export const approveOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('approveOffer', async (data, context) => {
    // Require admin role
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    try {
      const uid = context.auth.uid;
      const userDoc = await db.collection('users').doc(uid).get();
      const role = userDoc.data()?.role;

      if (role !== 'admin') {
        return { success: false, error: 'Admin role required' };
      }

      const { offerId } = data;
      if (!offerId) {
        return { success: false, error: 'offerId is required' };
      }

      await db.collection('offers').doc(offerId).update({
        status: 'active',
        approvedAt: new Date().toISOString(),
        approvedBy: uid
      });

      return {
        success: true,
        message: 'Offer approved'
      };
    } catch (err: any) {
      console.error('approveOffer error:', err);
      return {
        success: false,
        error: err.message || 'Failed to approve offer'
      };
    }
  }));

// =============================================================================
// IMPLEMENTATION: rejectOffer (Admin rejection)
// =============================================================================
export const rejectOffer = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('rejectOffer', async (data, context) => {
    // Require admin role
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    try {
      const uid = context.auth.uid;
      const userDoc = await db.collection('users').doc(uid).get();
      const role = userDoc.data()?.role;

      if (role !== 'admin') {
        return { success: false, error: 'Admin role required' };
      }

      const { offerId, reason } = data;
      if (!offerId) {
        return { success: false, error: 'offerId is required' };
      }

      await db.collection('offers').doc(offerId).update({
        status: 'rejected',
        rejectedAt: new Date().toISOString(),
        rejectedBy: uid,
        rejectionReason: reason || 'No reason provided'
      });

      return {
        success: true,
        message: 'Offer rejected'
      };
    } catch (err: any) {
      console.error('rejectOffer error:', err);
      return {
        success: false,
        error: err.message || 'Failed to reject offer'
      };
    }
  }));

// =============================================================================
// IMPLEMENTATION: calculateDailyStats (Daily statistics aggregation)
// =============================================================================
export const calculateDailyStats = functions
  .region('us-central1')
  .runWith({
    memory: '512MB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 5
  })
  .https.onCall(monitorFunction('calculateDailyStats', async (data, context) => {
    // Require admin role
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    try {
      const uid = context.auth.uid;
      const userDoc = await db.collection('users').doc(uid).get();
      const role = userDoc.data()?.role;

      if (role !== 'admin') {
        return { success: false, error: 'Admin role required' };
      }

      const today = new Date().toISOString().split('T')[0];

      // Calculate offer stats
      const offersSnap = await db.collection('offers').where('status', '==', 'active').get();
      const totalOffers = offersSnap.size;

      // Calculate redemptions (last 24h)
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const recentRedemptions = await db
        .collectionGroup('qr_tokens')
        .where('usedAt', '>=', oneDayAgo.toISOString())
        .get();

      const stats = {
        date: today,
        totalOffers,
        totalUsers: (await db.collection('users').get()).size,
        recentRedemptions: recentRedemptions.size,
        calculatedAt: new Date().toISOString()
      };

      await db.collection('admin_stats').doc(today).set(stats);

      return {
        success: true,
        stats
      };
    } catch (err: any) {
      console.error('calculateDailyStats error:', err);
      return {
        success: false,
        error: err.message || 'Failed to calculate stats'
      };
    }
  }));

// =============================================================================
// IMPLEMENTATION: getPointsHistory
// =============================================================================
export const getPointsHistory = functions
  .region('us-central1')
  .runWith({
    memory: '256MB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10
  })
  .https.onCall(monitorFunction('getPointsHistory', async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      return {
        success: false,
        error: 'Unauthenticated',
        history: []
      };
    }

    try {
      const userId = context.auth.uid;
      const limit = Math.min(data?.limit || 50, 100);
      
      // Query points transactions for this user
      const snapshot = await db
        .collection('points_transactions')
        .where('user_id', '==', userId)
        .orderBy('created_at', 'desc')
        .limit(limit)
        .get();
      
      const history = snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          timestamp: toIsoString(data.created_at) || new Date().toISOString(),
          points: data.points || data.amount || 0,
          description: data.description || data.reason || 'Points transaction'
        };
      });
      
      return {
        success: true,
        history
      };
    } catch (err: any) {
      console.error('getPointsHistory error:', err);
      return {
        success: false,
        error: err.message || 'Failed to fetch points history',
        history: []
      };
    }
  }));
