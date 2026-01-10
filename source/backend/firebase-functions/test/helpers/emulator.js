"use strict";
/**
 * Shared Test Harness for Firebase Emulator Testing
 * Provides consistent seed data and cleanup utilities
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getFirestore = getFirestore;
exports.clearFirestoreData = clearFirestoreData;
exports.createCustomer = createCustomer;
exports.createMerchant = createMerchant;
exports.createAdmin = createAdmin;
exports.createOffer = createOffer;
exports.createSubscription = createSubscription;
exports.createRedemption = createRedemption;
exports.createQRToken = createQRToken;
exports.futureTimestamp = futureTimestamp;
exports.pastTimestamp = pastTimestamp;
exports.startOfMonth = startOfMonth;
exports.startOfLastMonth = startOfLastMonth;
const admin = __importStar(require("firebase-admin"));
// Initialize once
let db;
function getFirestore() {
    if (!db) {
        db = admin.firestore();
    }
    return db;
}
/**
 * Clear all collections in Firestore emulator
 */
async function clearFirestoreData() {
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
async function createCustomer(customerId, data) {
    var _a, _b, _c;
    const db = getFirestore();
    const customerData = {
        name: data.name,
        email: data.email,
        points_balance: (_a = data.points_balance) !== null && _a !== void 0 ? _a : 0,
        tier: (_b = data.tier) !== null && _b !== void 0 ? _b : 'bronze',
        phone: (_c = data.phone) !== null && _c !== void 0 ? _c : '+96171234567',
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
async function createMerchant(merchantId, data) {
    var _a, _b, _c;
    const db = getFirestore();
    await db
        .collection('merchants')
        .doc(merchantId)
        .set({
        name: data.name,
        email: data.email,
        is_active: (_a = data.is_active) !== null && _a !== void 0 ? _a : true,
        offers_created_this_month: (_b = data.offers_created_this_month) !== null && _b !== void 0 ? _b : 0,
        compliance_status: (_c = data.compliance_status) !== null && _c !== void 0 ? _c : 'non_compliant',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function createAdmin(adminId, data) {
    var _a;
    const db = getFirestore();
    await db
        .collection('admins')
        .doc(adminId)
        .set({
        email: data.email,
        name: (_a = data.name) !== null && _a !== void 0 ? _a : 'Test Admin',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function createOffer(offerId, data) {
    var _a, _b;
    const db = getFirestore();
    await db
        .collection('offers')
        .doc(offerId)
        .set({
        title: data.title,
        description: data.description,
        merchant_id: data.merchant_id,
        points_cost: data.points_cost,
        status: (_a = data.status) !== null && _a !== void 0 ? _a : 'pending',
        is_active: (_b = data.is_active) !== null && _b !== void 0 ? _b : false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function createSubscription(subscriptionId, data) {
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
async function createRedemption(redemptionId, data) {
    var _a;
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
        created_at: (_a = data.created_at) !== null && _a !== void 0 ? _a : admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function createQRToken(tokenId, data) {
    var _a;
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
        used: (_a = data.used) !== null && _a !== void 0 ? _a : false,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Create future timestamp (for active subscriptions, unexpired tokens)
 */
function futureTimestamp(daysFromNow) {
    const date = new Date();
    date.setDate(date.getDate() + daysFromNow);
    return admin.firestore.Timestamp.fromDate(date);
}
/**
 * Create past timestamp (for expired tokens, old redemptions)
 */
function pastTimestamp(daysAgo) {
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);
    return admin.firestore.Timestamp.fromDate(date);
}
/**
 * Get start of current month
 */
function startOfMonth() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    return admin.firestore.Timestamp.fromDate(start);
}
/**
 * Get start of last month
 */
function startOfLastMonth() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    return admin.firestore.Timestamp.fromDate(start);
}
//# sourceMappingURL=emulator.js.map