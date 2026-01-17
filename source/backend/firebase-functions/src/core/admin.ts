/**
 * Core Admin Functions
 * Extracted for testability
 */

import * as admin from 'firebase-admin';

export interface DailyStatsRequest {
  date?: string;
}

export interface DailyStatsResponse {
  success: boolean;
  date?: string;
  stats?: {
    totalRedemptions: number;
    totalPointsRedeemed: number;
    uniqueCustomers: number;
    topMerchants: Array<{ merchantId: string; redemptionCount: number }>;
    averagePointsPerRedemption: number;
  };
  error?: string;
}

export interface AdminContext {
  auth?: {
    uid: string;
  };
}

export interface AdminDeps {
  db: admin.firestore.Firestore;
}

export async function coreCalculateDailyStats(
  data: DailyStatsRequest,
  context: AdminContext,
  deps: AdminDeps
): Promise<DailyStatsResponse> {
  try {
    if (!context.auth) {
      return { success: false, error: 'Unauthenticated' };
    }

    const userDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!userDoc.exists) {
      return { success: false, error: 'Admin access required' };
    }

    const targetDate = data.date ? new Date(data.date) : new Date();
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    const redemptionsSnapshot = await deps.db
      .collection('redemptions')
      .where('redeemed_at', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
      .where('redeemed_at', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
      .get();

    if (redemptionsSnapshot.empty) {
      return {
        success: true,
        date: targetDate.toISOString().split('T')[0],
        stats: {
          totalRedemptions: 0,
          totalPointsRedeemed: 0,
          uniqueCustomers: 0,
          topMerchants: [],
          averagePointsPerRedemption: 0,
        },
      };
    }

    let totalPointsRedeemed = 0;
    const uniqueCustomers = new Set<string>();
    const merchantCounts = new Map<string, number>();

    redemptionsSnapshot.docs.forEach((doc) => {
      const redemption = doc.data();
      totalPointsRedeemed += redemption.points_cost || 0;
      uniqueCustomers.add(redemption.user_id);

      const currentCount = merchantCounts.get(redemption.merchant_id) || 0;
      merchantCounts.set(redemption.merchant_id, currentCount + 1);
    });

    const topMerchants = Array.from(merchantCounts.entries())
      .map(([merchantId, count]) => ({ merchantId, redemptionCount: count }))
      .sort((a, b) => b.redemptionCount - a.redemptionCount)
      .slice(0, 10);

    const stats = {
      totalRedemptions: redemptionsSnapshot.size,
      totalPointsRedeemed,
      uniqueCustomers: uniqueCustomers.size,
      topMerchants,
      averagePointsPerRedemption: totalPointsRedeemed / redemptionsSnapshot.size,
    };

    return {
      success: true,
      date: targetDate.toISOString().split('T')[0],
      stats,
    };
  } catch (error) {
    console.error('Error calculating daily stats:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

export interface ApproveOfferRequest {
  offerId: string;
}

export interface ApproveOfferResponse {
  success: boolean;
  message?: string;
  error?: string;
}

export async function coreApproveOffer(
  data: ApproveOfferRequest,
  context: AdminContext,
  deps: AdminDeps
): Promise<ApproveOfferResponse> {
  try {
    if (!context.auth) {
      return Promise.reject(new Error('unauthenticated:Authentication required'));
    }

    const adminDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      return Promise.reject(new Error('permission-denied:Admin access required'));
    }

    const offerRef = deps.db.collection('offers').doc(data.offerId);
    const offerDoc = await offerRef.get();

    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }

    const offer = offerDoc.data()!;

      if (offer.status === 'active') {
      return { success: false, error: 'Offer already approved' };
    }

    await offerRef.update({
        status: 'active',
      is_active: true,
      approved_by: context.auth.uid,
      approved_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: 'Offer approved successfully',
    };
  } catch (error) {
    console.error('Error approving offer:', error);
    if (error instanceof Error && error.message.includes(':')) {
      throw error;
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

export async function coreRejectOffer(
  data: { offerId: string; reason?: string },
  context: AdminContext,
  deps: AdminDeps
): Promise<ApproveOfferResponse> {
  try {
    if (!context.auth) {
      return Promise.reject(new Error('unauthenticated:Authentication required'));
    }

    const adminDoc = await deps.db.collection('admins').doc(context.auth.uid).get();
    if (!adminDoc.exists) {
      return Promise.reject(new Error('permission-denied:Admin access required'));
    }

    const offerRef = deps.db.collection('offers').doc(data.offerId);
    const offerDoc = await offerRef.get();

    if (!offerDoc.exists) {
      return { success: false, error: 'Offer not found' };
    }

    await offerRef.update({
      status: 'rejected',
      is_active: false,
      rejected_by: context.auth.uid,
      rejected_at: admin.firestore.FieldValue.serverTimestamp(),
      rejection_reason: data.reason || 'Not specified',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: 'Offer rejected successfully',
    };
  } catch (error) {
    console.error('Error rejecting offer:', error);
    if (error instanceof Error && error.message.includes(':')) {
      throw error;
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Internal error',
    };
  }
}

export async function coreGetMerchantComplianceStatus(deps: { db: admin.firestore.Firestore }) {
  const merchantsSnapshot = await deps.db
    .collection('merchants')
    .orderBy('compliance_status', 'asc')
    .get();

  const merchants = merchantsSnapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    offersThisMonth: doc.data().offers_created_this_month || 0,
    complianceStatus: doc.data().compliance_status || 'unknown',
    lastChecked: doc.data().compliance_last_checked,
  }));

  return { success: true, merchants };
}

export async function coreCheckMerchantCompliance(deps: { db: admin.firestore.Firestore }) {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

  const merchantsSnapshot = await deps.db.collection('merchants').get();
  const complianceResults = [];

  for (const merchantDoc of merchantsSnapshot.docs) {
    const merchantId = merchantDoc.id;

    const offersThisMonth = await deps.db
      .collection('offers')
      .where('merchant_id', '==', merchantId)
      .where('created_at', '>=', admin.firestore.Timestamp.fromDate(startOfMonth))
      .where('created_at', '<=', admin.firestore.Timestamp.fromDate(endOfMonth))
      .get();

    const offerCount = offersThisMonth.size;
    const isCompliant = offerCount >= 5;

    await merchantDoc.ref.update({
      offers_created_this_month: offerCount,
      compliance_status: isCompliant ? 'compliant' : 'non_compliant',
      compliance_last_checked: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    complianceResults.push({ merchantId, offerCount, isCompliant });
  }

  return { success: true, results: complianceResults };
}
