# Urban Points Lebanon - Firestore Collection Schemas

**Version:** 3.0  
**Last Updated:** January 14, 2026  
**Purpose:** Complete documentation of all Firestore collections, their schemas, indexes, and retention policies.

---

## Table of Contents

1. [User Collections](#user-collections)
2. [Points & Transactions](#points--transactions)
3. [Offers & Redemptions](#offers--redemptions)
4. [Subscriptions & Payments](#subscriptions--payments)
5. [Authentication & Security](#authentication--security)
6. [Notifications & Campaigns](#notifications--campaigns)
7. [Audit & Logs](#audit--logs)
8. [System Configuration](#system-configuration)

---

## User Collections

### `customers`

**Purpose:** Store customer profile data and points balance

**Schema:**
```typescript
{
  id: string;                      // Auto-generated document ID (matches auth UID)
  email: string;                   // User email
  name: string;                    // Full name
  phone_number?: string;           // Verified phone number
  phone_verified: boolean;         // WhatsApp verification status
  phone_verified_at?: Timestamp;   // Verification timestamp
  points_balance: number;          // Current points balance
  points_lifetime: number;         // Total points earned (lifetime)
  subscription_status: string;     // 'free' | 'active' | 'past_due' | 'cancelled'
  subscription_plan?: string;      // Plan ID reference
  subscription_end_date?: Timestamp;
  created_at: Timestamp;
  updated_at: Timestamp;
  sms_opt_out: boolean;           // Marketing opt-out flag
  preferred_language: string;      // 'en' | 'ar'
}
```

**Indexes:**
- `email` ASC
- `phone_number` ASC
- `subscription_status` ASC, `subscription_end_date` ASC

**Security:** User can read/write own document; admins can read all

**Retention:** Permanent (until user deletion request)

---

### `merchants`

**Purpose:** Store merchant profile and compliance data

**Schema:**
```typescript
{
  id: string;
  name: string;
  email: string;
  phone_number?: string;
  phone_verified: boolean;
  business_name: string;
  business_address: string;
  business_license?: string;
  subscription_status: string;     // 'active' | 'past_due' | 'cancelled'
  subscription_plan?: string;
  subscription_end_date?: Timestamp;
  stripe_customer_id?: string;
  active_offer_count: number;      // Cached count for compliance
  compliance_status: string;       // 'compliant' | 'warning' | 'non_compliant'
  is_visible: boolean;             // Hidden if non-compliant
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**Indexes:**
- `subscription_status` ASC, `subscription_end_date` ASC
- `compliance_status` ASC
- `is_visible` ASC, `active_offer_count` ASC

**Security:** Merchant can read/write own document; admins can read all

**Retention:** Permanent

---

## Points & Transactions

### `points_transactions`

**Purpose:** Record all points earning and redemption events

**Schema:**
```typescript
{
  id: string;
  user_id: string;                 // Reference to customers
  merchant_id?: string;            // Reference to merchants (if applicable)
  type: string;                    // 'earn' | 'redeem' | 'expire' | 'transfer'
  amount: number;                  // Points amount (positive or negative)
  balance_before: number;
  balance_after: number;
  reason: string;                  // Description of transaction
  offer_id?: string;               // Reference to offers (if redemption)
  redemption_id?: string;          // Reference to redemptions
  expires_at?: Timestamp;          // Expiry date for earned points
  created_at: Timestamp;
  metadata?: object;               // Additional context
}
```

**Indexes:**
- `user_id` ASC, `created_at` DESC
- `type` ASC, `created_at` DESC
- `expires_at` ASC (for expiry cleanup)

**Security:** User can read own transactions; admins can read all

**Retention:** 2 years

---

### `points_expiry_events`

**Purpose:** Track scheduled points expirations

**Schema:**
```typescript
{
  id: string;
  user_id: string;
  transaction_id: string;          // Original earning transaction
  points_amount: number;
  expires_at: Timestamp;
  processed: boolean;
  processed_at?: Timestamp;
  created_at: Timestamp;
}
```

**Indexes:**
- `expires_at` ASC, `processed` ASC
- `user_id` ASC, `processed` ASC

**Security:** Admin only

**Retention:** 90 days after processing

---

## Offers & Redemptions

### `offers`

**Purpose:** Store merchant offers

**Schema:**
```typescript
{
  id: string;
  merchant_id: string;
  title: string;
  description: string;
  type: string;                    // 'percentage' | 'fixed_value' | 'buy1get1'
  points: number;                  // Points required for redemption
  quota: number;                   // Total available redemptions
  quota_remaining: number;
  status: string;                  // 'pending' | 'active' | 'paused' | 'expired' | 'cancelled'
  start_date: Timestamp;
  end_date: Timestamp;
  created_at: Timestamp;
  updated_at: Timestamp;
  redemption_count: number;        // Cached count
  images?: string[];               // Image URLs
  terms_and_conditions?: string;
}
```

**Indexes:**
- `merchant_id` ASC, `status` ASC
- `status` ASC, `end_date` ASC
- `status` ASC, `start_date` ASC

**Security:** Merchant can read/write own offers; users can read active offers; admins can read/write all

**Retention:** Permanent (archived after expiry)

---

### `redemptions`

**Purpose:** Record all offer redemptions

**Schema:**
```typescript
{
  id: string;
  customer_id: string;
  merchant_id: string;
  offer_id: string;
  qr_token: string;                // Used QR token
  status: string;                  // 'pending' | 'completed' | 'failed' | 'cancelled'
  points_deducted: number;
  failure_reason?: string;
  created_at: Timestamp;
  completed_at?: Timestamp;
  metadata?: object;
}
```

**Indexes:**
- `customer_id` ASC, `created_at` DESC
- `merchant_id` ASC, `created_at` DESC
- `offer_id` ASC, `created_at` DESC
- `status` ASC, `created_at` DESC

**Security:** User can read own redemptions; merchant can read redemptions for their offers; admins can read all

**Retention:** 2 years

---

## Subscriptions & Payments

### `subscriptions`

**Purpose:** Store user/merchant subscription records

**Schema:**
```typescript
{
  id: string;
  user_id: string;
  merchant_id?: string;
  plan_id: string;
  payment_method: string;          // 'stripe' | 'manual'
  status: string;                  // 'active' | 'past_due' | 'cancelled' | 'expired'
  start_date: Timestamp;
  end_date: Timestamp;
  auto_renew: boolean;
  stripe_subscription_id?: string;
  stripe_customer_id?: string;
  manual_payment_id?: string;      // Reference to manual_payments
  last_renewed_at?: Timestamp;
  renewal_count: number;
  grace_period_end?: Timestamp;
  cancelled_at?: Timestamp;
  created_at: Timestamp;
}
```

**Indexes:**
- `user_id` ASC, `status` ASC
- `merchant_id` ASC, `status` ASC
- `status` ASC, `end_date` ASC
- `auto_renew` ASC, `end_date` ASC

**Security:** User can read own subscriptions; admins can read/write all

**Retention:** Permanent

---

### `subscription_plans`

**Purpose:** Define available subscription tiers

**Schema:**
```typescript
{
  id: string;                      // e.g., 'customer_basic', 'merchant_pro'
  plan_id: string;                 // Same as document ID
  name: string;
  description: string;
  price: number;                   // Price in USD
  price_lbp: number;               // Price in Lebanese Pounds
  currency: string;                // 'USD' | 'LBP'
  interval: string;                // 'month' | 'year'
  points_per_month: number;
  features: string[];
  stripe_price_id?: string;
  is_active: boolean;
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**Indexes:**
- `is_active` ASC, `price` ASC

**Security:** All users can read; admins can write

**Retention:** Permanent

---

### `manual_payments`

**Purpose:** Track manual payment submissions (Whish/OMT)

**Schema:**
```typescript
{
  id: string;
  user_id: string;
  merchant_id?: string;
  service: string;                 // 'WHISH' | 'OMT'
  amount: number;
  currency: string;                // 'LBP' | 'USD'
  receipt_number: string;          // Format: WM-YYYY-XXXXXX or OMT-YYYY-XXXXXX
  agent_name?: string;
  agent_location?: string;
  paid_at: Timestamp;
  submitted_at: Timestamp;
  status: string;                  // 'pending' | 'approved' | 'rejected'
  processed: boolean;
  approval_note?: string;
  approved_by?: string;            // Admin UID
  approved_at?: Timestamp;
  subscription_id?: string;        // Created subscription reference
  plan_id?: string;
}
```

**Indexes:**
- `status` ASC, `submitted_at` DESC
- `user_id` ASC, `status` ASC
- `receipt_number` ASC

**Security:** User can read own payments and create new; admins can read/write all

**Retention:** 3 years (financial records)

---

## Authentication & Security

### `otp_codes`

**Purpose:** Store active OTP codes for phone verification

**Schema:**
```typescript
{
  id: string;                      // Document ID is phone number
  code: string;                    // 6-digit code
  expires_at: Timestamp;           // 5 minutes from creation
  attempts: number;                // Max 3 attempts
  created_at: Timestamp;
  channel: string;                 // 'sms' | 'whatsapp'
}
```

**Indexes:**
- `expires_at` ASC (for TTL cleanup)

**Security:** System only (no user access)

**Retention:** 5 minutes (TTL index)

---

### `qr_tokens`

**Purpose:** Store generated QR tokens for redemption

**Schema:**
```typescript
{
  id: string;
  token: string;                   // HMAC signed token
  customer_id: string;
  expires_at: Timestamp;           // 60 seconds
  pin: string;                     // 4-digit PIN
  used: boolean;
  used_at?: Timestamp;
  revoked: boolean;
  created_at: Timestamp;
}
```

**Indexes:**
- `token` ASC
- `expires_at` ASC (for TTL cleanup)
- `customer_id` ASC, `created_at` DESC

**Security:** System only

**Retention:** 7 days

---

### `qr_history`

**Purpose:** Audit trail of QR token generation and usage

**Schema:**
```typescript
{
  id: string;
  token_id: string;
  customer_id: string;
  action: string;                  // 'generated' | 'scanned' | 'validated' | 'revoked'
  actor_id?: string;               // Who performed the action
  success: boolean;
  failure_reason?: string;
  timestamp: Timestamp;
  metadata?: object;
}
```

**Indexes:**
- `customer_id` ASC, `timestamp` DESC
- `action` ASC, `timestamp` DESC

**Security:** Admin only

**Retention:** 90 days

---

## Notifications & Campaigns

### `notifications`

**Purpose:** Store in-app notifications for users

**Schema:**
```typescript
{
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: string;                    // 'offer' | 'points' | 'subscription' | 'system'
  is_read: boolean;
  link?: string;                   // Deep link
  created_at: Timestamp;
  read_at?: Timestamp;
}
```

**Indexes:**
- `user_id` ASC, `is_read` ASC, `created_at` DESC

**Security:** User can read/write own notifications; admins can create

**Retention:** 30 days

---

### `campaign_logs`

**Purpose:** Track push campaign delivery

**Schema:**
```typescript
{
  id: string;
  campaign_id: string;
  user_id?: string;
  topic?: string;
  title: string;
  body: string;
  status: string;                  // 'sent' | 'delivered' | 'failed'
  fcm_message_id?: string;
  sent_at: Timestamp;
  delivered_at?: Timestamp;
  error?: string;
}
```

**Indexes:**
- `campaign_id` ASC, `sent_at` DESC
- `user_id` ASC, `sent_at` DESC

**Security:** Admin only

**Retention:** 90 days

---

### `device_tokens`

**Purpose:** Store FCM device tokens for push notifications

**Schema:**
```typescript
{
  id: string;                      // Device token as ID
  user_id: string;
  platform: string;                // 'android' | 'ios' | 'web'
  topics: string[];                // Subscribed topics
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**Indexes:**
- `user_id` ASC

**Security:** User can register/update own tokens; system can read all

**Retention:** Permanent (cleaned when invalid)

---

## Audit & Logs

### `audit_logs`

**Purpose:** Track all admin and critical user actions

**Schema:**
```typescript
{
  id: string;
  action: string;                  // Action type
  actor_id: string;                // User/admin who performed action
  actor_role: string;              // 'customer' | 'merchant' | 'admin'
  target_id?: string;              // Affected resource ID
  target_type?: string;            // 'offer' | 'user' | 'payment' | etc.
  details: object;                 // Action-specific data
  ip_address?: string;
  user_agent?: string;
  timestamp: Timestamp;
}
```

**Indexes:**
- `actor_id` ASC, `timestamp` DESC
- `action` ASC, `timestamp` DESC
- `target_type` ASC, `target_id` ASC, `timestamp` DESC

**Security:** Admin only

**Retention:** 90 days (configurable for compliance)

---

### `whatsapp_log`

**Purpose:** Audit trail of WhatsApp messages sent

**Schema:**
```typescript
{
  id: string;
  recipient: string;               // Phone number
  message: string;
  type: string;                    // 'otp' | 'notification' | 'promotional'
  status: string;                  // 'sent' | 'failed'
  messageId?: string;              // Twilio message SID
  whatsapp_id?: string;
  provider: string;                // 'twilio'
  sent_at: Timestamp;
  error?: string;
}
```

**Indexes:**
- `recipient` ASC, `sent_at` DESC
- `type` ASC, `sent_at` DESC

**Security:** Admin only

**Retention:** 90 days

---

### `whatsapp_verification_log`

**Purpose:** Track successful phone verifications

**Schema:**
```typescript
{
  id: string;
  phone_number: string;
  verified_at: Timestamp;
  user_id: string;                 // 'anonymous' if not logged in
}
```

**Indexes:**
- `phone_number` ASC, `verified_at` DESC
- `user_id` ASC, `verified_at` DESC

**Security:** Admin only

**Retention:** 1 year

---

### `sms_log`

**Purpose:** Audit trail of SMS messages (fallback)

**Schema:**
```typescript
{
  id: string;
  recipient: string;
  message: string;
  type: string;
  status: string;
  provider: string;                // 'touch' | 'alfa' | 'twilio'
  messageId?: string;
  sent_at: Timestamp;
}
```

**Indexes:**
- `recipient` ASC, `sent_at` DESC

**Security:** Admin only

**Retention:** 90 days

---

## System Configuration

### `system_config`

**Purpose:** Store system-wide configuration

**Schema:**
```typescript
{
  id: string;                      // Config key (e.g., 'maintenance_mode')
  value: any;                      // Config value
  description: string;
  updated_by: string;              // Admin UID
  updated_at: Timestamp;
}
```

**Indexes:** None

**Security:** Admin write; all read

**Retention:** Permanent

---

### `payment_agents`

**Purpose:** List of Whish/OMT agent locations (optional)

**Schema:**
```typescript
{
  id: string;
  service: string;                 // 'WHISH' | 'OMT'
  name: string;
  address: string;
  city: string;
  phone?: string;
  hours?: string;
  latitude?: number;
  longitude?: number;
  is_active: boolean;
}
```

**Indexes:**
- `service` ASC, `city` ASC
- `is_active` ASC

**Security:** All users can read; admins can write

**Retention:** Permanent

---

## TTL Indexes Summary

Configure Firebase TTL (Time-To-Live) policies for automatic cleanup:

| Collection | TTL Field | Retention |
|------------|-----------|-----------|
| `otp_codes` | `expires_at` | 5 minutes |
| `qr_tokens` | `expires_at` | 60 seconds |
| `notifications` | `created_at` | 30 days |
| `qr_history` | `timestamp` | 90 days |
| `campaign_logs` | `sent_at` | 90 days |
| `audit_logs` | `timestamp` | 90 days |
| `whatsapp_log` | `sent_at` | 90 days |
| `sms_log` | `sent_at` | 90 days |
| `points_expiry_events` | `processed_at` | 90 days (if processed) |

---

## Migration Notes

**From v2 to v3:**
1. Added `points_expiry_events` collection
2. Added `qr_history` collection
3. Added `campaign_logs` collection
4. Added `device_tokens` collection
5. Added `subscription_plans` collection
6. Added `system_config` collection
7. Added `payment_agents` collection
8. Updated `subscriptions` to include `payment_method` and `manual_payment_id`
9. Updated `customers` and `merchants` to include `phone_verified` fields

**Deprecated Collections:**
- None (all collections preserved for backward compatibility)

---

## Security Rules Summary

All collections follow these general principles:
1. Users can only read/write their own documents
2. Admins have full read/write access
3. Merchants can read/write their own resources
4. System-only collections (OTP, QR tokens) have no direct user access
5. Audit logs are admin-read-only

See `source/infra/firestore.rules` for complete security rules.

---

**Document Version:** 3.0  
**Maintained by:** Engineering Team  
**Last Review:** January 14, 2026
