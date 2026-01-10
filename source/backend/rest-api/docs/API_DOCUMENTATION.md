# 🚀 Urban Points Lebanon - API Documentation

## Table of Contents
- [Overview](#overview)
- [Authentication](#authentication)
- [API Endpoints](#api-endpoints)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Lebanon-Specific Features](#lebanon-specific-features)

## Overview

**Base URL:** `http://localhost:3000/api`  
**Environment:** Production  
**Database:** Neon PostgreSQL 17.5  
**Timezone:** Asia/Beirut  
**Country:** Lebanon (LB)  
**Payments:** Disabled (PAYMENTS_ENABLED=false)

### Technology Stack
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Language:** TypeScript
- **Database:** PostgreSQL 17.5 (Neon.tech)
- **Authentication:** JWT (JSON Web Tokens)
- **Security:** Helmet, CORS, Rate Limiting

---

## Authentication

All authenticated endpoints require a JWT token in the Authorization header:

```bash
Authorization: Bearer <your_jwt_token>
```

### Register New User
**Endpoint:** `POST /api/auth/register`

**Request Body:**
```json
{
  "phone": "+96170123456",
  "email": "user@example.com",
  "full_name": "John Doe",
  "password": "SecurePassword123!"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "phone": "+96170123456",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user",
      "points_balance": 0
    }
  }
}
```

### Login
**Endpoint:** `POST /api/auth/login`

**Request Body:**
```json
{
  "phone": "+96170123456",
  "password": "SecurePassword123!"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "phone": "+96170123456",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user",
      "points_balance": 250
    }
  }
}
```

---

## API Endpoints

### System Endpoints

#### Health Check
**Endpoint:** `GET /api/health`  
**Authentication:** Not required

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "timestamp_utc": "2025-11-02T14:58:51.170095+00:00",
    "timestamp_beirut": "2025-11-02 16:58:51.170095",
    "tz": "Asia/Beirut",
    "database": "connected",
    "flags": {
      "PAYMENTS_ENABLED": false,
      "GIFTS_DISABLE": false,
      "REDEMPTION_DISABLE": false
    },
    "country": "LB",
    "version": "1.0.0"
  }
}
```

#### Feature Flags
**Endpoint:** `GET /api/feature-flags`  
**Authentication:** Not required

**Response:**
```json
{
  "success": true,
  "data": [
    { "key": "PAYMENTS_ENABLED", "enabled": false, "description": "Enable payment processing" },
    { "key": "GIFTS_DISABLE", "enabled": false, "description": "Disable gift functionality" }
  ]
}
```

---

### User Endpoints

#### Get Current User Profile
**Endpoint:** `GET /api/users/me`  
**Authentication:** Required

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "phone": "+96170123456",
    "email": "user@example.com",
    "full_name": "John Doe",
    "role": "user",
    "points_balance": 250,
    "is_active": true,
    "last_login_at": "2025-11-02T14:30:00Z"
  }
}
```

#### Get User's Vouchers
**Endpoint:** `GET /api/users/me/vouchers`  
**Authentication:** Required

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "voucher-uuid",
      "code": "VOC-1730554800-ABC123",
      "status": "available",
      "expires_at": "2025-12-02T00:00:00Z",
      "offer_title": "BOGOF Main Course at Mayrig",
      "offer_description": "Buy one main course, get one free",
      "merchant_name": "Mayrig",
      "merchant_category": "Restaurant"
    }
  ]
}
```

#### Get User's Transaction History
**Endpoint:** `GET /api/users/me/transactions?limit=50&offset=0`  
**Authentication:** Required

**Query Parameters:**
- `limit` (optional): Number of transactions to return (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "transaction-uuid",
      "type": "redeem",
      "points": -100,
      "description": "Redeemed: BOGOF Main Course at Mayrig",
      "reference_id": "offer-uuid",
      "reference_type": "offer",
      "created_at": "2025-11-02T14:00:00Z"
    }
  ]
}
```

---

### Merchant Endpoints

#### Get All Merchants
**Endpoint:** `GET /api/merchants`  
**Authentication:** Not required

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "merchant-uuid",
      "name": "Mayrig",
      "category": "Restaurant",
      "address": "Gemmayzeh, Beirut",
      "phone": "+9611570700",
      "email": "info@mayrig.com",
      "logo_url": "https://example.com/logos/mayrig.png",
      "description": "Traditional Armenian cuisine",
      "is_active": true
    }
  ]
}
```

#### Get Merchant Details
**Endpoint:** `GET /api/merchants/:id`  
**Authentication:** Not required

**Response:** Same as above, single merchant object

#### Get Merchant's Offers
**Endpoint:** `GET /api/merchants/:id/offers`  
**Authentication:** Not required

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "offer-uuid",
      "title": "BOGOF Main Course",
      "description": "Buy one main course, get one free",
      "points_cost": 100,
      "valid_from": "2025-01-01T00:00:00Z",
      "valid_until": "2025-12-31T23:59:59Z",
      "terms_conditions": "Valid for parties of 2-8 people. Blackout dates apply.",
      "is_active": true
    }
  ]
}
```

---

### Offer Endpoints

#### Get All Active Offers
**Endpoint:** `GET /api/offers`  
**Authentication:** Not required

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "offer-uuid",
      "title": "BOGOF Main Course at Mayrig",
      "description": "Buy one main course, get one free",
      "points_cost": 100,
      "valid_from": "2025-01-01T00:00:00Z",
      "valid_until": "2025-12-31T23:59:59Z",
      "merchant_name": "Mayrig",
      "merchant_category": "Restaurant",
      "merchant_logo": "https://example.com/logos/mayrig.png",
      "is_active": true
    }
  ]
}
```

#### Get Offer Details
**Endpoint:** `GET /api/offers/:id`  
**Authentication:** Not required

**Response:** Same as above, single offer object with merchant details

#### Purchase Offer (Get Voucher)
**Endpoint:** `POST /api/offers/:id/purchase`  
**Authentication:** Required

**Success Response (201):**
```json
{
  "success": true,
  "message": "Voucher purchased successfully",
  "data": {
    "voucher": {
      "id": "voucher-uuid",
      "code": "VOC-1730554800-ABC123",
      "status": "available",
      "issued_at": "2025-11-02T14:00:00Z",
      "expires_at": "2025-12-02T14:00:00Z"
    },
    "new_balance": 150
  }
}
```

**Error Response (400 - Insufficient Points):**
```json
{
  "success": false,
  "error": "Insufficient points balance"
}
```

---

### Voucher Endpoints

#### Validate Voucher Redemption
**Endpoint:** `POST /api/vouchers/:id/validate`  
**Authentication:** Not required

**Request Body:**
```json
{
  "party_size": 4,
  "redemption_date": "2025-11-15"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "is_valid": true,
    "reasons": []
  }
}
```

**Validation Failed Response:**
```json
{
  "success": true,
  "data": {
    "is_valid": false,
    "reasons": [
      "Party size must be between 2 and 8",
      "Redemption date falls on blackout date (2025-01-01)"
    ]
  }
}
```

#### Redeem Voucher
**Endpoint:** `POST /api/vouchers/:id/redeem`  
**Authentication:** Required

**Request Body:**
```json
{
  "party_size": 4,
  "redemption_date": "2025-11-15",
  "notes": "Celebrating anniversary"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Voucher redeemed successfully",
  "data": {
    "redemption_id": "redemption-uuid",
    "party_size": 4,
    "redemption_date": "2025-11-15"
  }
}
```

**Validation Failed Response (400):**
```json
{
  "success": false,
  "error": "Voucher validation failed",
  "reasons": ["Voucher has already been redeemed"]
}
```

---

### Gift Endpoints

#### Send Voucher as Gift
**Endpoint:** `POST /api/vouchers/:id/gift`  
**Authentication:** Required

**Request Body:**
```json
{
  "recipient_phone": "+96170987654",
  "message": "Happy birthday! Enjoy dinner on me!"
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Gift sent successfully",
  "data": {
    "gift_id": "gift-uuid",
    "status": "pending"
  }
}
```

#### Get Received Gifts
**Endpoint:** `GET /api/gifts/received`  
**Authentication:** Required

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "gift-uuid",
      "voucher_code": "VOC-1730554800-ABC123",
      "offer_title": "BOGOF Main Course at Mayrig",
      "sender_name": "Jane Doe",
      "sender_phone": "+96170123456",
      "message": "Happy birthday! Enjoy dinner on me!",
      "status": "pending",
      "sent_at": "2025-11-02T14:00:00Z"
    }
  ]
}
```

#### Accept Gift
**Endpoint:** `POST /api/gifts/:id/accept`  
**Authentication:** Required

**Success Response (200):**
```json
{
  "success": true,
  "message": "Gift accepted successfully"
}
```

#### Reject Gift
**Endpoint:** `POST /api/gifts/:id/reject`  
**Authentication:** Required

**Success Response (200):**
```json
{
  "success": true,
  "message": "Gift rejected successfully"
}
```

---

## Error Handling

All errors follow this format:

```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

### Common HTTP Status Codes
- `200 OK` - Successful request
- `201 Created` - Resource created successfully
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Missing or invalid authentication token
- `403 Forbidden` - User lacks permission
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource already exists (e.g., phone number already registered)
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

---

## Rate Limiting

- **Window:** 15 minutes (900,000ms)
- **Max Requests:** 100 per IP address
- **Scope:** All `/api/` endpoints

When rate limit is exceeded:
```json
{
  "message": "Too many requests from this IP, please try again later."
}
```

---

## Lebanon-Specific Features

### Timezone
All timestamps are in UTC but can be converted to Asia/Beirut timezone. The `/api/health` endpoint provides both UTC and Beirut timestamps.

### Blackout Dates (2025)
BOGOF vouchers cannot be redeemed on these Lebanese holidays:
- **2025-01-01** - New Year's Day
- **2025-03-30** - Easter Sunday (Orthodox)
- **2025-04-18** - Good Friday
- **2025-04-21** - Easter Monday
- **2025-05-01** - Labour Day
- **2025-08-15** - Assumption of Mary
- **2025-11-22** - Independence Day

### Party Size Validation
BOGOF vouchers require party size between **2 and 8 people**.

### Payments
Payment processing is **disabled** for Lebanon deployment (`PAYMENTS_ENABLED=false`).

---

## Example Usage

### Complete User Journey Example

```bash
# 1. Register a new user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+96170123456",
    "email": "user@example.com",
    "full_name": "John Doe",
    "password": "SecurePassword123!"
  }'

# 2. Login and get token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+96170123456",
    "password": "SecurePassword123!"
  }'

# 3. Get all offers
curl http://localhost:3000/api/offers

# 4. Purchase an offer (use token from step 2)
curl -X POST http://localhost:3000/api/offers/OFFER_ID/purchase \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 5. Get your vouchers
curl http://localhost:3000/api/users/me/vouchers \
  -H "Authorization: Bearer YOUR_TOKEN"

# 6. Validate voucher redemption
curl -X POST http://localhost:3000/api/vouchers/VOUCHER_ID/validate \
  -H "Content-Type: application/json" \
  -d '{
    "party_size": 4,
    "redemption_date": "2025-11-15"
  }'

# 7. Redeem voucher
curl -X POST http://localhost:3000/api/vouchers/VOUCHER_ID/redeem \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "party_size": 4,
    "redemption_date": "2025-11-15"
  }'
```

---

## Support

For API issues or questions, contact the development team or check:
- **Server Logs:** `/home/user/urban-points-api/api.log`
- **Database Monitoring:** Use monitoring views created in database
- **Health Endpoint:** `/api/health` for system status

---

**Document Version:** 1.0.0  
**Last Updated:** November 2, 2025  
**API Version:** 1.0.0
