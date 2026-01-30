/**
 * Shared Test Harness for Firebase Emulator Testing
 * Provides consistent seed data and cleanup utilities
 */

import * as admin from 'firebase-admin';

// Initialize once
let db: admin.firestore.Firestore;

export function getFirestore(): admin.firestore.Firestore {
  if (!db) {
    db = admin.firestore();
  }
  return db;
}

/**
 * Clear all collections in Firestore emulator
 */
export async function clearFirestoreData(): Promise<void> {
  const db = getFirestore();
  const collections = [
    'customers',
    'merchants',
    'admins',
    'offers',
    'qr_tokens',
    'redemptions',
    'subscriptions',
    'subscription_plans',
    'payment_transactions',
    'rate_limits',
    'system_alerts',
    'notifications',
    'daily_stats',
    'otp_codes',
    'sms_log',
    'campaign_logs',
    'subscription_metrics',
    'transactions',
    'rewards',
    'referrals',
  ];

  for (const collection of collections) {
    const snapshot = await db.collection(collection).get();
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

/**
 * Seed Helpers - Create test data in Firestore
 */

export async function createCustomer(
  customerId: string,
  data: {
    name: string;
    email: string;
    points_balance?: number;
    tier?: string;
    phone?: string;
    subscription_status?: string;
    subscription_expiry?: admin.firestore.Timestamp;
  }
): Promise<void> {
  const db = getFirestore();
  const customerData: any = {
    name: data.name,
    email: data.email,
    points_balance: data.points_balance ?? 0,
    tier: data.tier ?? 'bronze',
    phone: data.phone ?? '+96171234567',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Add subscription fields if provided
  if (data.subscription_status) {
    customerData.subscription_status = data.subscription_status;
  }
  if (data.subscription_expiry) {
    customerData.subscription_expiry = data.subscription_expiry;
  }

  await db.collection('customers').doc(customerId).set(customerData);
}

export async function createMerchant(
  merchantId: string,
  data: {
    name: string;
    email: string;
    is_active?: boolean;
    offers_created_this_month?: number;
    compliance_status?: string;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('merchants')
    .doc(merchantId)
    .set({
      name: data.name,
      email: data.email,
      is_active: data.is_active ?? true,
      offers_created_this_month: data.offers_created_this_month ?? 0,
      compliance_status: data.compliance_status ?? 'non_compliant',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

export async function createAdmin(
  adminId: string,
  data: {
    email: string;
    name?: string;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('admins')
    .doc(adminId)
    .set({
      email: data.email,
      name: data.name ?? 'Test Admin',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

export async function createOffer(
  offerId: string,
  data: {
    title: string;
    description: string;
    merchant_id: string;
    points_cost: number;
    status?: string;
    is_active?: boolean;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('offers')
    .doc(offerId)
    .set({
      title: data.title,
      description: data.description,
      merchant_id: data.merchant_id,
      points_cost: data.points_cost,
      status: data.status ?? 'pending',
      is_active: data.is_active ?? false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

export async function createSubscription(
  subscriptionId: string,
  data: {
    user_id: string;
    status: string;
    expires_at: admin.firestore.Timestamp;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('subscriptions')
    .doc(subscriptionId)
    .set({
      user_id: data.user_id,
      status: data.status,
      expires_at: data.expires_at,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

export async function createRedemption(
  redemptionId: string,
  data: {
    user_id: string;
    offer_id: string;
    merchant_id: string;
    status: string;
    points_awarded: number;
    created_at?: admin.firestore.Timestamp;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('redemptions')
    .doc(redemptionId)
    .set({
      user_id: data.user_id,
      offer_id: data.offer_id,
      merchant_id: data.merchant_id,
      status: data.status,
      points_awarded: data.points_awarded,
      created_at: data.created_at ?? admin.firestore.FieldValue.serverTimestamp(),
    });
}

export async function createQRToken(
  tokenId: string,
  data: {
    user_id: string;
    merchant_id: string;
    offer_id: string;
    token: string;
    display_code: string;
    expires_at: admin.firestore.Timestamp;
    used?: boolean;
  }
): Promise<void> {
  const db = getFirestore();
  await db
    .collection('qr_tokens')
    .doc(tokenId)
    .set({
      user_id: data.user_id,
      merchant_id: data.merchant_id,
      offer_id: data.offer_id,
      token: data.token,
      display_code: data.display_code,
      expires_at: data.expires_at,
      used: data.used ?? false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * Create future timestamp (for active subscriptions, unexpired tokens)
 */
export function futureTimestamp(daysFromNow: number): admin.firestore.Timestamp {
  const date = new Date();
  date.setDate(date.getDate() + daysFromNow);
  return admin.firestore.Timestamp.fromDate(date);
}

/**
 * Create past timestamp (for expired tokens, old redemptions)
 */
export function pastTimestamp(daysAgo: number): admin.firestore.Timestamp {
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  return admin.firestore.Timestamp.fromDate(date);
}

/**
 * Get start of current month
 */
export function startOfMonth(): admin.firestore.Timestamp {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  return admin.firestore.Timestamp.fromDate(start);
}

/**
 * Get start of last month
 */
export function startOfLastMonth(): admin.firestore.Timestamp {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  return admin.firestore.Timestamp.fromDate(start);
}
