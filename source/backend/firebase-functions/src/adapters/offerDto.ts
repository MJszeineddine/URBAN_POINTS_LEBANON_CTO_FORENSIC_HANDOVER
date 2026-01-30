/**
 * Offer DTO Adapter - Converts raw Firestore offer data to Flutter contract
 * 
 * Flutter expects:
 * - id, title, description
 * - points_required, points_cost (not points_value)
 * - image_url (not imageUrl)
 * - valid_until (ISO string, not Timestamp)
 * - is_active (not isActive)
 * - discount_percentage (not discountPercentage)
 * - created_at (ISO string)
 * - merchant_id, merchant_name, category
 * - distance_km (optional numeric)
 * - used (optional boolean, default false)
 */

import { toIsoString } from './time';

export interface OfferDTO {
  id: string;
  title: string;
  description: string;
  points_required: number;
  points_cost: number;
  image_url: string;
  valid_until: string | null;
  is_active: boolean;
  discount_percentage: number;
  created_at: string | null;
  merchant_id: string;
  merchant_name: string;
  category: string;
  distance_km?: number;
  used?: boolean;
}

/**
 * Converts raw Firestore offer data to Flutter OfferDTO contract
 * @param input - Raw offer data from Firestore
 * @param used - Optional flag indicating if the offer has been used by the current user
 * @returns OfferDTO matching Flutter contract
 */
export function toOfferDTO(input: any, used: boolean = false): OfferDTO {
  if (!input) {
    throw new Error('Cannot convert null/undefined to OfferDTO');
  }

  // Ensure id is present
  const id = input.id || input.offerId || input.offer_id;
  if (!id) {
    throw new Error('Offer must have an id field');
  }

  // Map points fields (prefer explicit field names, fallback to points_value)
  const pointsValue = input.points_value || input.pointsValue || 0;
  const pointsRequired = input.points_required ?? input.pointsRequired ?? pointsValue;
  const pointsCost = input.points_cost ?? input.pointsCost ?? pointsValue;

  // Map image URL (handle both snake_case and camelCase)
  const imageUrl = input.image_url || input.imageUrl || '';

  // Map valid_until to ISO string
  const validUntil = toIsoString(input.valid_until || input.validUntil || input.expiryDate || input.expiry_date);

  // Map is_active (handle both formats)
  const isActive = input.is_active ?? input.isActive ?? true;

  // Map discount_percentage (handle both formats)
  const discountPercentage = input.discount_percentage ?? input.discountPercentage ?? 0;

  // Map created_at to ISO string
  const createdAt = toIsoString(input.created_at || input.createdAt || null);

  // Map merchant fields
  const merchantId = input.merchant_id || input.merchantId || '';
  const merchantName = input.merchant_name || input.merchantName || '';

  // Map category
  const category = input.category || '';

  // Map optional distance (if present)
  const distanceKm = typeof input.distance_km === 'number' ? input.distance_km :
                     typeof input.distanceKm === 'number' ? input.distanceKm :
                     typeof input.distance === 'number' ? input.distance :
                     undefined;

  return {
    id,
    title: input.title || '',
    description: input.description || '',
    points_required: pointsRequired,
    points_cost: pointsCost,
    image_url: imageUrl,
    valid_until: validUntil,
    is_active: isActive,
    discount_percentage: discountPercentage,
    created_at: createdAt,
    merchant_id: merchantId,
    merchant_name: merchantName,
    category,
    distance_km: distanceKm,
    used
  };
}
