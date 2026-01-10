/**
 * Core Offers Logic - Production Ready
 * 
 * Features:
 * - Complete offer lifecycle management
 * - Validation (quota, time limits)
 * - Status flow: draft → pending → active → expired
 * - Expiration handling
 * - Stats aggregation
 * - Audit logging
 */

import * as admin from 'firebase-admin';

// ============================================================================
// INTERFACES
// ============================================================================

export interface CreateOfferRequest {
  merchantId: string;
  title: string;
  description: string;
  pointsValue: number;
  quota: number;
  validFrom: string; // ISO date
  validUntil: string; // ISO date
  terms?: string;
  category?: string;
  merchantLocation?: {
    latitude: number;
    longitude: number;
  };
}

export interface CreateOfferResponse {
  success: boolean;
  offerId?: string;
  status?: string;
  error?: string;
}

export interface UpdateOfferStatusRequest {
  offerId: string;
  status: 'draft' | 'pending' | 'active' | 'expired' | 'cancelled';
  reason?: string;
}

export interface UpdateOfferStatusResponse {
  success: boolean;
  offerId?: string;
  newStatus?: string;
  error?: string;
}

export interface HandleOfferExpirationResponse {
  success: boolean;
  expiredCount?: number;
  offerIds?: string[];
  error?: string;
}

export interface AggregateOfferStatsRequest {
  offerId: string;
}

export interface AggregateOfferStatsResponse {
  success: boolean;
  stats?: {
    offerId: string;
    title: string;
    totalRedemptions: number;
    uniqueCustomers: number;
    totalPointsAwarded: number;
    averagePointsPerRedemption: number;
    quotaUsed: number;
    quotaRemaining: number;
    revenueImpact: number; // Points * conversion rate
  };
  error?: string;
}

export interface OffersContext {
  auth?: {
    uid: string;
  };
}

export interface OffersDeps {
  db: admin.firestore.Firestore;
}

// ============================================================================
// PHASE 1B: PRODUCTION-READY OFFERS ENGINE
// ============================================================================

/**
 * createOffer - Create new offer with validation
 * 
 * Requirements:
 * ✅ Validation: quota > 0, validUntil > now
 * ✅ Status: draft (initial state)
 * ✅ Merchant verification
 * ✅ Audit logging
 * 
 * @param data - Offer creation request
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Offer creation response
 */
export async function createOffer(
  data: CreateOfferRequest,
  context: OffersContext,
  deps: OffersDeps
): Promise<CreateOfferResponse> {
  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Verify merchant owns this request
    if (context.auth.uid !== data.merchantId) {
      return { success: false, error: 'Merchant ID mismatch' };
    }

    // Validate required fields
    if (!data.title || !data.description || !data.merchantId) {
      return { success: false, error: 'Missing required fields' };
    }

    // Validate points value
    if (data.pointsValue == null || data.pointsValue <= 0) {
      return { success: false, error: 'Points value must be greater than 0' };
    }

    // Validate quota
    if (data.quota == null || data.quota <= 0) {
      return { success: false, error: 'Quota must be greater than 0' };
    }

    // Validate dates
    const validFrom = new Date(data.validFrom);
    const validUntil = new Date(data.validUntil);
    const now = new Date();

    if (isNaN(validFrom.getTime())) {
      return { success: false, error: 'Invalid validFrom date' };
    }

    if (isNaN(validUntil.getTime())) {
      return { success: false, error: 'Invalid validUntil date' };
    }

    if (validUntil <= now) {
      return { success: false, error: 'validUntil must be in the future' };
    }

    if (validUntil <= validFrom) {
      return { success: false, error: 'validUntil must be after validFrom' };
    }

    // Verify merchant exists and has active subscription
    const merchantRef = deps.db.collection('merchants').doc(data.merchantId);
    const merchantDoc = await merchantRef.get();
    
    if (!merchantDoc.exists) {
      return { success: false, error: 'Merchant not found' };
    }

    // Qatar Spec: Enforce active subscription requirement for offer creation
    const merchantData = merchantDoc.data()!;
    const subscriptionStatus = merchantData.subscription_status;
    const hasActiveSubscription = subscriptionStatus === 'active';
    
    // Check grace period for past_due subscriptions
    let withinGracePeriod = false;
    if (subscriptionStatus === 'past_due' && merchantData.grace_period_end) {
      const gracePeriodEnd = merchantData.grace_period_end.toDate?.() || new Date(merchantData.grace_period_end);
      withinGracePeriod = new Date() < gracePeriodEnd;
    }
    
    if (!hasActiveSubscription && !withinGracePeriod) {
      return { success: false, error: 'Active subscription required to create offers. Please update your payment method.' };
    }

    // Create offer document
    const offerData = {
      merchant_id: data.merchantId,
      title: data.title,
      description: data.description,
      points_value: data.pointsValue,
      quota: data.quota,
      quota_used: 0,
      valid_from: admin.firestore.Timestamp.fromDate(validFrom),
      valid_until: admin.firestore.Timestamp.fromDate(validUntil),
      terms: data.terms || '',
      category: data.category || 'general',
      merchant_location: data.merchantLocation || null,
      status: 'draft', // Initial status
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    const offerRef = await deps.db.collection('offers').add(offerData);

    // Create audit log
    await deps.db.collection('audit_logs').add({
      operation: 'offer_created',
      user_id: data.merchantId,
      target_id: offerRef.id,
      data: {
        title: data.title,
        pointsValue: data.pointsValue,
        quota: data.quota,
        validFrom: data.validFrom,
        validUntil: data.validUntil,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update merchant's offer count
    const currentMonth = new Date().toISOString().slice(0, 7); // YYYY-MM
    await merchantRef.update({
      offers_created_this_month: admin.firestore.FieldValue.increment(1),
      last_offer_created_month: currentMonth,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      offerId: offerRef.id,
      status: 'draft',
    };
  } catch (error) {
    console.error('Error creating offer:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * updateOfferStatus - Update offer status with validation
 * 
 * Requirements:
 * ✅ Status flow: draft → pending → active → expired/cancelled
 * ✅ Prevent invalid transitions
 * ✅ Admin approval for pending → active
 * ✅ Audit logging
 * 
 * @param data - Status update request
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Status update response
 */
export async function updateOfferStatus(
  data: UpdateOfferStatusRequest,
  context: OffersContext,
  deps: OffersDeps
): Promise<UpdateOfferStatusResponse> {
  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Validate input
    if (!data.offerId || !data.status) {
      return { success: false, error: 'Missing required fields' };
    }

    const validStatuses = ['draft', 'pending', 'active', 'expired', 'cancelled'];
    if (!validStatuses.includes(data.status)) {
      return { success: false, error: 'Invalid status' };
    }

    // Get offer
    const offerRef = deps.db.collection('offers').doc(data.offerId);
    const offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }

    const offer = offerDoc.data()!;
    const currentStatus = offer.status;

    // Verify ownership or admin rights
    const isOwner = context.auth.uid === offer.merchant_id;
    const isAdmin = await checkAdminRole(context.auth.uid, deps.db);

    if (!isOwner && !isAdmin) {
      return { success: false, error: 'Permission denied' };
    }

    // Validate status transitions
    const allowedTransitions: { [key: string]: string[] } = {
      draft: ['pending', 'cancelled'],
      pending: ['active', 'cancelled'], // Only admin can approve
      active: ['expired', 'cancelled'],
      expired: [], // Terminal state
      cancelled: [], // Terminal state
    };

    const allowed = allowedTransitions[currentStatus] || [];
    if (!allowed.includes(data.status)) {
      return {
        success: false,
        error: `Invalid transition: ${currentStatus} → ${data.status}`,
      };
    }

    // Admin-only transitions
    if (currentStatus === 'pending' && data.status === 'active' && !isAdmin) {
      return { success: false, error: 'Only admins can approve offers' };
    }

    // Update offer status
    await offerRef.update({
      status: data.status,
      status_reason: data.reason || '',
      status_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      status_updated_by: context.auth.uid,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create audit log
    await deps.db.collection('audit_logs').add({
      operation: 'offer_status_updated',
      user_id: context.auth.uid,
      target_id: data.offerId,
      data: {
        previousStatus: currentStatus,
        newStatus: data.status,
        reason: data.reason,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      offerId: data.offerId,
      newStatus: data.status,
    };
  } catch (error) {
    console.error('Error updating offer status:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * handleOfferExpiration - Mark expired offers
 * 
 * Requirements:
 * ✅ Find offers past validUntil
 * ✅ Mark as expired
 * ✅ Return count and IDs
 * ✅ Scheduled cleanup (manual trigger for now)
 * 
 * @param deps - Dependencies (db)
 * @returns Expiration response
 */
export async function handleOfferExpiration(
  deps: OffersDeps
): Promise<HandleOfferExpirationResponse> {
  try {
    const now = admin.firestore.Timestamp.now();

    // Find active offers that have expired
    const expiredOffersQuery = await deps.db
      .collection('offers')
      .where('status', '==', 'active')
      .where('valid_until', '<=', now)
      .get();

    if (expiredOffersQuery.empty) {
      return {
        success: true,
        expiredCount: 0,
        offerIds: [],
      };
    }

    const batch = deps.db.batch();
    const expiredIds: string[] = [];

    for (const doc of expiredOffersQuery.docs) {
      batch.update(doc.ref, {
        status: 'expired',
        status_reason: 'Automatic expiration',
        status_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create audit log
      const auditRef = deps.db.collection('audit_logs').doc();
      batch.set(auditRef, {
        operation: 'offer_expired',
        user_id: 'system',
        target_id: doc.id,
        data: {
          title: doc.data().title,
          validUntil: doc.data().valid_until,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      expiredIds.push(doc.id);
    }

    await batch.commit();

    return {
      success: true,
      expiredCount: expiredIds.length,
      offerIds: expiredIds,
    };
  } catch (error) {
    console.error('Error handling offer expiration:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

/**
 * aggregateOfferStats - Calculate offer statistics
 * 
 * Requirements:
 * ✅ Redemption count
 * ✅ Unique customers
 * ✅ Total points awarded
 * ✅ Revenue impact
 * ✅ Quota usage
 * 
 * @param data - Stats request
 * @param context - Auth context
 * @param deps - Dependencies (db)
 * @returns Stats response
 */
export async function aggregateOfferStats(
  data: AggregateOfferStatsRequest,
  context: OffersContext,
  deps: OffersDeps
): Promise<AggregateOfferStatsResponse> {
  try {
    // Auth check
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    // Validate input
    if (!data.offerId) {
      return { success: false, error: 'Missing offerId' };
    }

    // Get offer
    const offerRef = deps.db.collection('offers').doc(data.offerId);
    const offerDoc = await offerRef.get();
    
    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }

    const offer = offerDoc.data()!;

    // Verify ownership or admin rights
    const isOwner = context.auth.uid === offer.merchant_id;
    const isAdmin = await checkAdminRole(context.auth.uid, deps.db);

    if (!isOwner && !isAdmin) {
      return { success: false, error: 'Permission denied' };
    }

    // Get all redemptions for this offer
    const redemptionsQuery = await deps.db
      .collection('redemptions')
      .where('offer_id', '==', data.offerId)
      .where('status', '==', 'completed')
      .get();

    const uniqueCustomers = new Set<string>();
    let totalPointsAwarded = 0;
    let totalRedemptions = 0;

    for (const doc of redemptionsQuery.docs) {
      const redemption = doc.data();
      uniqueCustomers.add(redemption.customer_id);
      totalPointsAwarded += redemption.points_awarded || 0;
      totalRedemptions++;
    }

    const averagePointsPerRedemption = totalRedemptions > 0 
      ? Math.round(totalPointsAwarded / totalRedemptions) 
      : 0;

    const quotaUsed = offer.quota_used || 0;
    const quotaRemaining = offer.quota - quotaUsed;

    // Revenue impact (assuming $0.01 per point as conversion rate)
    const conversionRate = 0.01;
    const revenueImpact = Math.round(totalPointsAwarded * conversionRate * 100) / 100;

    return {
      success: true,
      stats: {
        offerId: data.offerId,
        title: offer.title,
        totalRedemptions,
        uniqueCustomers: uniqueCustomers.size,
        totalPointsAwarded,
        averagePointsPerRedemption,
        quotaUsed,
        quotaRemaining,
        revenueImpact,
      },
    };
  } catch (error) {
    console.error('Error aggregating offer stats:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

// ============================================================================
// OFFER BROWSING & SEARCH
// ============================================================================

export interface GetOffersByLocationRequest {
  latitude?: number;
  longitude?: number;
  radius?: number; // kilometers, default 50
  limit?: number; // max results, default 50
  status?: 'active' | 'all'; // default 'active'
}

export interface OfferWithDistance {
  offerId: string;
  merchantId: string;
  title: string;
  description: string;
  pointsValue: number;
  quota: number;
  quotaUsed: number;
  validFrom: string;
  validUntil: string;
  terms?: string;
  category?: string;
  distance?: number; // kilometers from user location
  merchantLocation?: {
    latitude: number;
    longitude: number;
  };
  status: string;
}

export interface GetOffersByLocationResponse {
  success: boolean;
  offers?: OfferWithDistance[];
  totalCount?: number;
  error?: string;
}

/**
 * Qatar Spec Requirement: Offers prioritized by user location + full national catalog
 * 
 * - If user provides location: Sort by distance (nearest first)
 * - If no location: Return all active offers in creation order
 * - Always include option to view full catalog nationally
 * 
 * @param data - Location request (lat, lng, radius, limit)
 * @param deps - Dependencies (db)
 * @returns Offers sorted by distance (if location provided)
 */
export async function getOffersByLocation(
  data: GetOffersByLocationRequest,
  deps: OffersDeps
): Promise<GetOffersByLocationResponse> {
  try {
    const limit = data.limit || 50;
    const radius = data.radius || 50; // km default
    const status = data.status || 'active';

    // Base query: Get all active offers (or all offers if requested)
    let query = deps.db.collection('offers');
    if (status === 'active') {
      query = query.where('status', '==', 'active') as any;
    }
    query = (query as any).orderBy('created_at', 'desc').limit(limit * 2); // Fetch extra for filtering

    const snapshot = await query.get();
    const allOffers: any[] = [];

    // Build list of offers with calculated distances
    for (const doc of snapshot.docs) {
      const offerData = doc.data();
      let distance = null;

      // Calculate distance if location provided
      if (data.latitude !== undefined && data.longitude !== undefined && offerData.merchant_location) {
        const merchantLat = offerData.merchant_location.latitude;
        const merchantLng = offerData.merchant_location.longitude;
        distance = calculateDistance(
          data.latitude,
          data.longitude,
          merchantLat,
          merchantLng
        );

        // Skip if beyond radius
        if (distance > radius) {
          continue;
        }
      }

      allOffers.push({
        offerId: doc.id,
        merchantId: offerData.merchant_id,
        title: offerData.title,
        description: offerData.description,
        pointsValue: offerData.points_value,
        quota: offerData.quota,
        quotaUsed: offerData.quota_used || 0,
        validFrom: offerData.valid_from?.toDate().toISOString(),
        validUntil: offerData.valid_until?.toDate().toISOString(),
        terms: offerData.terms,
        category: offerData.category,
        distance: distance,
        merchantLocation: offerData.merchant_location,
        status: offerData.status,
      });
    }

    // Sort by distance if location provided
    if (data.latitude !== undefined && data.longitude !== undefined) {
      allOffers.sort((a, b) => (a.distance || Infinity) - (b.distance || Infinity));
    }

    // Apply limit
    const offers = allOffers.slice(0, limit);

    return {
      success: true,
      offers,
      totalCount: offers.length,
    };
  } catch (error) {
    console.error('Error fetching offers by location:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch offers',
    };
  }
}

/**
 * Haversine formula to calculate distance between two coordinates
 * @returns Distance in kilometers
 */
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Check if user has admin role
 */
async function checkAdminRole(uid: string, db: admin.firestore.Firestore): Promise<boolean> {
  try {
    const adminDoc = await db.collection('admins').doc(uid).get();
    return adminDoc.exists;
  } catch (error) {
    console.error('Error checking admin role:', error);
    return false;
  }
}
