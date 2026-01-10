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
// VALIDATION HELPER
// ============================================================================

export function validateInput<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}
