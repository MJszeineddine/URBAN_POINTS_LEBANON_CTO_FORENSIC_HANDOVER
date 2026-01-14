import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Logger from './logger';

const db = admin.firestore();

async function assertAdmin(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  const adminDoc = await db.collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }
  return context.auth.uid;
}

export const adminUpdateUserRole = functions.https.onCall(async (data, context) => {
  const actorId = await assertAdmin(context);
  const { userId, role } = data || {};
  if (!userId || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and role are required');
  }
  if (!['customer', 'merchant', 'admin'].includes(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'role must be customer, merchant, or admin');
  }

  await admin.auth().setCustomUserClaims(userId, { role });
  await db.collection('users').doc(userId).update({
    role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    roleUpdatedBy: actorId,
  });
  Logger.info('Admin updated user role', { actorId, userId, role });
  return { success: true, userId, role };
});

export const adminBanUser = functions.https.onCall(async (data, context) => {
  const actorId = await assertAdmin(context);
  const { userId } = data || {};
  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  await db.collection('users').doc(userId).update({
    banned: true,
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    bannedBy: actorId,
  });
  try {
    await admin.auth().updateUser(userId, { disabled: true });
  } catch (err) {
    Logger.warn('Failed to disable auth user during ban', { userId, err });
  }
  Logger.info('Admin banned user', { actorId, userId });
  return { success: true, userId, banned: true };
});

export const adminUnbanUser = functions.https.onCall(async (data, context) => {
  const actorId = await assertAdmin(context);
  const { userId } = data || {};
  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId is required');
  }

  await db.collection('users').doc(userId).update({
    banned: false,
    bannedAt: null,
    bannedBy: actorId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  try {
    await admin.auth().updateUser(userId, { disabled: false });
  } catch (err) {
    Logger.warn('Failed to re-enable auth user during unban', { userId, err });
  }
  Logger.info('Admin unbanned user', { actorId, userId });
  return { success: true, userId, banned: false };
});

export const adminUpdateMerchantStatus = functions.https.onCall(async (data, context) => {
  const actorId = await assertAdmin(context);
  const { merchantId, action } = data || {};
  if (!merchantId || !action) {
    throw new functions.https.HttpsError('invalid-argument', 'merchantId and action are required');
  }
  if (!['suspend', 'activate', 'block'].includes(action)) {
    throw new functions.https.HttpsError('invalid-argument', 'action must be suspend, activate, or block');
  }

  const merchantRef = db.collection('merchants').doc(merchantId);
  const baseUpdate: Record<string, unknown> = {
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_by: actorId,
  };

  if (action === 'suspend') {
    Object.assign(baseUpdate, { status: 'suspended', suspendedAt: admin.firestore.FieldValue.serverTimestamp() });
  } else if (action === 'activate') {
    Object.assign(baseUpdate, { status: 'active', suspendedAt: null, blocked: false, blockedAt: null });
  } else if (action === 'block') {
    Object.assign(baseUpdate, { status: 'blocked', blocked: true, blockedAt: admin.firestore.FieldValue.serverTimestamp() });
  }

  await merchantRef.update(baseUpdate);
  Logger.info('Admin updated merchant status', { actorId, merchantId, action });
  return { success: true, merchantId, action };
});

export const adminDisableOffer = functions.https.onCall(async (data, context) => {
  const actorId = await assertAdmin(context);
  const { offerId, reason } = data || {};
  if (!offerId) {
    throw new functions.https.HttpsError('invalid-argument', 'offerId is required');
  }

  const offerRef = db.collection('offers').doc(offerId);
  await offerRef.update({
    status: 'cancelled',
    is_active: false,
    disabled_at: admin.firestore.FieldValue.serverTimestamp(),
    disabled_by: actorId,
    disabled_reason: reason || 'disabled_by_admin',
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection('audit_logs').add({
    operation: 'offer_disabled',
    user_id: actorId,
    target_id: offerId,
    data: { reason: reason || 'disabled_by_admin' },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  Logger.info('Admin disabled offer', { actorId, offerId });
  return { success: true, offerId, status: 'cancelled' };
});
