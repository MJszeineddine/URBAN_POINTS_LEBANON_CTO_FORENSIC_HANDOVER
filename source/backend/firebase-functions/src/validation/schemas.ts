/**
 * Input Validation Schemas
 * Using Zod for runtime type checking and validation
 */

import { z } from 'zod';

// ============================================================================
// POINTS ENGINE SCHEMAS
// ============================================================================

export const ProcessPointsEarningSchema = z.object({
  customerId: z.string().min(1, 'Customer ID required'),
  merchantId: z.string().min(1, 'Merchant ID required'),
  offerId: z.string().min(1, 'Offer ID required'),
  amount: z.number().positive('Amount must be positive').max(100000, 'Amount too large'),
  redemptionId: z.string().min(1, 'Redemption ID required'),
});

export const ProcessRedemptionSchema = z.object({
  customerId: z.string().min(1, 'Customer ID required'),
  offerId: z.string().min(1, 'Offer ID required'),
  qrToken: z.string().min(1, 'QR token required'),
  merchantId: z.string().min(1, 'Merchant ID required'),
});

export const GetPointsBalanceSchema = z.object({
  customerId: z.string().min(1, 'Customer ID required'),
});

// ============================================================================
// OFFERS ENGINE SCHEMAS
// ============================================================================

export const CreateOfferSchema = z.object({
  merchantId: z.string().min(1, 'Merchant ID required'),
  title: z.string().min(3, 'Title must be at least 3 characters').max(200, 'Title too long'),
  description: z.string().min(10, 'Description must be at least 10 characters').max(2000, 'Description too long'),
  pointsValue: z.number().positive('Points value must be positive').max(100000, 'Points value too large'),
  quota: z.number().positive('Quota must be positive').max(100000, 'Quota too large'),
  validFrom: z.string().refine((val) => !isNaN(Date.parse(val)), 'Invalid date format'),
  validUntil: z.string().refine((val) => !isNaN(Date.parse(val)), 'Invalid date format'),
  terms: z.string().optional(),
  category: z.string().optional(),
});

export const UpdateOfferStatusSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
  status: z.enum(['draft', 'pending', 'active', 'expired', 'cancelled']),
  reason: z.string().optional(),
});

export const AggregateOfferStatsSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
});

// ============================================================================
// STRIPE SCHEMAS
// ============================================================================

export const InitiatePaymentSchema = z.object({
  merchantId: z.string().min(1, 'Merchant ID required'),
  planId: z.string().min(1, 'Plan ID required'),
  paymentMethodId: z.string().optional(),
});

// ============================================================================
// V3: QR TOKEN SCHEMAS
// ============================================================================

export const GenerateQRTokenSchema = z.object({
  userId: z.string().min(1, 'User ID required'),
  offerId: z.string().min(1, 'Offer ID required'),
  merchantId: z.string().min(1, 'Merchant ID required'),
  deviceHash: z.string().min(1, 'Device hash required'),
  geoLat: z.number().min(-90).max(90).optional(),
  geoLng: z.number().min(-180).max(180).optional(),
  partySize: z.number().int().positive().max(50).optional(),
});

export const ValidatePINSchema = z.object({
  merchantId: z.string().min(1, 'Merchant ID required'),
  displayCode: z.string().min(6).max(6, 'Display code must be 6 digits'),
  pin: z.string().min(6).max(6, 'PIN must be 6 digits'),
});

export const RevokeQRTokenSchema = z.object({
  tokenId: z.string().min(1, 'Token ID required'),
  reason: z.string().min(5, 'Reason must be at least 5 characters').max(500, 'Reason too long'),
});

export const GetQRHistorySchema = z.object({
  customerId: z.string().optional(),
  merchantId: z.string().optional(),
  action: z.enum(['generated', 'scanned', 'validated', 'revoked', 'expired']).optional(),
  limit: z.number().int().positive().max(100).optional(),
});

export const DetectFraudPatternsSchema = z.object({
  customerId: z.string().optional(),
  deviceHash: z.string().optional(),
}).refine((data) => data.customerId || data.deviceHash, {
  message: 'Either customerId or deviceHash must be provided',
});

// ============================================================================
// V3: OFFER EDIT & CANCEL SCHEMAS
// ============================================================================

export const EditOfferSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
  title: z.string().min(3).max(200).optional(),
  description: z.string().min(10).max(2000).optional(),
  validUntil: z.string().refine((val) => !isNaN(Date.parse(val)), 'Invalid date format').optional(),
  terms: z.string().max(5000).optional(),
  category: z.string().max(100).optional(),
}).refine((data) => data.title || data.description || data.validUntil || data.terms || data.category, {
  message: 'At least one field must be provided for editing',
});

export const CancelOfferSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
  reason: z.string().min(10, 'Reason must be at least 10 characters').max(1000, 'Reason too long'),
});

export const GetOfferEditHistorySchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
});

// ============================================================================
// V3: POINTS EXPIRATION & TRANSFER SCHEMAS
// ============================================================================

export const ExpirePointsSchema = z.object({
  dryRun: z.boolean().optional(),
});

export const TransferPointsSchema = z.object({
  fromCustomerId: z.string().min(1, 'From customer ID required'),
  toCustomerId: z.string().min(1, 'To customer ID required'),
  amount: z.number().positive('Amount must be positive').max(100000, 'Amount too large'),
  reason: z.string().min(5, 'Reason must be at least 5 characters').max(500, 'Reason too long'),
});

// ============================================================================
// ADMIN & MODERATION SCHEMAS
// ============================================================================

export const ApproveOfferSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
  reason: z.string().optional(),
});

export const RejectOfferSchema = z.object({
  offerId: z.string().min(1, 'Offer ID required'),
  reason: z.string().min(5, 'Reason must be at least 5 characters').max(500, 'Reason too long'),
});

export const GetMerchantComplianceSchema = z.object({
  merchantId: z.string().min(1, 'Merchant ID required'),
});

export const GetOffersByLocationSchema = z.object({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  radius: z.number().positive().max(100).optional(),
  limit: z.number().int().positive().max(100).optional(),
});

// ============================================================================
// FCM PUSH NOTIFICATION SCHEMAS
// ============================================================================

export const RegisterFCMTokenSchema = z.object({
  token: z.string().min(50, 'Invalid FCM token').max(500, 'Token too long'),
  platform: z.enum(['ios', 'android', 'web']),
  deviceId: z.string().min(1, 'Device ID required').max(200, 'Device ID too long'),
});

export const UnregisterFCMTokenSchema = z.object({
  token: z.string().min(50, 'Invalid FCM token').max(500, 'Token too long'),
});

export const CreateCampaignSchema = z.object({
  title: z.string().min(3, 'Title too short').max(100, 'Title too long'),
  message: z.string().min(10, 'Message too short').max(500, 'Message too long'),
  targetAudience: z.enum(['all', 'customers', 'merchants', 'custom']),
  customUserIds: z.array(z.string()).optional(),
  scheduledAt: z.string().refine((val) => !isNaN(Date.parse(val)), 'Invalid date format').optional(),
  imageUrl: z.string().url('Invalid image URL').optional(),
  actionUrl: z.string().url('Invalid action URL').optional(),
}).refine((data) => {
  if (data.targetAudience === 'custom') {
    return data.customUserIds && data.customUserIds.length > 0;
  }
  return true;
}, {
  message: 'Custom user IDs required for custom audience',
  path: ['customUserIds'],
});

export const SendCampaignSchema = z.object({
  campaignId: z.string().min(1, 'Campaign ID required'),
});

export const GetCampaignStatsSchema = z.object({
  campaignId: z.string().optional(),
  limit: z.number().int().positive().max(100).optional(),
});

// ============================================================================
// VALIDATION HELPER
// ============================================================================

export function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}
