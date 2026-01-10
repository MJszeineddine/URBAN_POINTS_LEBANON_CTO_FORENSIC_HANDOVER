// Database Enums
export enum UserRole {
  ADMIN = 'admin',
  MERCHANT = 'merchant',
  USER = 'user'
}

export enum TransactionType {
  EARN = 'earn',
  REDEEM = 'redeem',
  GIFT_SEND = 'gift_send',
  GIFT_RECEIVE = 'gift_receive',
  ADJUSTMENT = 'adjustment'
}

export enum GiftStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  EXPIRED = 'expired'
}

export enum RedemptionStatus {
  SUCCESS = 'success',
  PENDING = 'pending',
  FAILED = 'failed'
}

export enum SettlementCurrency {
  LBP = 'LBP',
  USD = 'USD'
}

export enum OtpStatus {
  PENDING = 'pending',
  SENT = 'sent',
  DELIVERED = 'delivered',
  FAILED = 'failed',
  EXPIRED = 'expired'
}

// Database Models
export interface User {
  id: string;
  phone: string;
  email: string | null;
  full_name: string;
  role: UserRole;
  points_balance: number;
  is_active: boolean;
  last_login_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

export interface Merchant {
  id: string;
  name: string;
  category: string;
  address: string | null;
  phone: string | null;
  email: string | null;
  logo_url: string | null;
  description: string | null;
  is_active: boolean;
  owner_user_id: string;
  created_at: Date;
  updated_at: Date;
}

export interface Offer {
  id: string;
  merchant_id: string;
  title: string;
  description: string | null;
  points_cost: number;
  valid_from: Date;
  valid_until: Date;
  terms_conditions: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface Voucher {
  id: string;
  offer_id: string;
  owner_user_id: string;
  code: string;
  status: 'available' | 'redeemed' | 'expired' | 'gifted';
  issued_at: Date;
  expires_at: Date;
  redeemed_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

export interface VoucherRedemption {
  id: string;
  voucher_id: string;
  merchant_id: string;
  redeemed_by_user_id: string;
  party_size: number;
  redemption_date: Date;
  status: RedemptionStatus;
  notes: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface Gift {
  id: string;
  voucher_id: string;
  sender_user_id: string;
  recipient_user_id: string;
  status: GiftStatus;
  message: string | null;
  sent_at: Date;
  responded_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

export interface Transaction {
  id: string;
  user_id: string;
  type: TransactionType;
  points: number;
  description: string | null;
  reference_id: string | null;
  reference_type: string | null;
  created_at: Date;
}

export interface FeatureFlag {
  key: string;
  enabled: boolean;
  description: string | null;
  updated_at: Date;
}

// API Request/Response Types
export interface RegisterRequest {
  phone: string;
  email?: string;
  full_name: string;
  password: string;
}

export interface LoginRequest {
  phone: string;
  password: string;
}

export interface AuthResponse {
  token: string;
  refreshToken: string;
  user: Omit<User, 'created_at' | 'updated_at'>;
}

export interface RedeemVoucherRequest {
  voucher_id: string;
  party_size: number;
  redemption_date?: string; // YYYY-MM-DD format
}

export interface GiftVoucherRequest {
  voucher_id: string;
  recipient_phone: string;
  message?: string;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
  sort?: string;
  order?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  success: boolean;
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Validation Response Types
export interface ValidationResult {
  is_valid: boolean;
  reasons: string[];
  voucher?: Voucher;
  offer?: Offer;
}

// JWT Payload
export interface JwtPayload {
  userId: string;
  phone: string;
  role: UserRole;
  iat?: number;
  exp?: number;
}

// Express Request Extension
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}
