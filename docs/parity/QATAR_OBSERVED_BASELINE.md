# QATAR OBSERVED BASELINE SPECIFICATION

Purpose: Observed single source of truth for Qatar-like parity  
Confidence Levels: VERIFIED / PARTIALLY VERIFIED / NOT VERIFIED  
Coverage Target: ~90–92% (publicly observable)

---

## 1. PRODUCT & ACCESS

### Subscription Model (VERIFIED)
- App is publicly browsable
- Offer usage requires active subscription
- Customer subscription: ~$8/month
- Merchant subscription: ~$20/month
- Merchant must publish minimum 5 offers

### Authentication (VERIFIED)
- Phone number + OTP

### Language (VERIFIED)
- Arabic + English

---

## 2. OFFER TYPES (VERIFIED)
- Buy 1 Get 1
- Percentage discount
- Fixed-value vouchers
- Mixed offer types supported

---

## 3. CUSTOMER FLOW

### Browsing (VERIFIED)
- All users can browse offers
- Offers prioritized by user location
- Users can view all offers nationally

### Redemption Rules (VERIFIED)
- Each offer usable once
- Offer expires immediately after use
- Used offers marked as "Used"
- Redemption stored in history

### Redemption Security (PARTIALLY VERIFIED)
- QR generated from customer app
- QR validity ~30–60 seconds
- Merchant scans QR
- One-time PIN generated in Merchant App
- PIN rotates every redemption

---

## 4. MERCHANT FLOW

### Merchant App (VERIFIED)
- Dedicated Merchant Application exists

### Offer Creation (VERIFIED)
- Merchant creates offers
- Admin approval required before publishing

### Merchant Subscription (VERIFIED)
- Merchant pays monthly subscription
- If subscription expires:
  - Offers hidden from customers
  - Offers marked inactive in Merchant App

---

## 5. ADMIN & CONTROL

### Admin Capabilities (VERIFIED)
- View all redemptions
- Approve / reject offers
- Disable offers post-publication
- Suspend merchants

### Abuse & Fraud (NOT VERIFIED)
- No confirmed automatic fraud rules
- Manual admin intervention assumed

---

## 6. LOCATION & NOTIFICATIONS

### Location Logic (VERIFIED)
- Offers prioritized by proximity
- Full national catalog available

### Notifications (VERIFIED)
- Push notifications for:
  - New offers
  - Subscription renewal reminders
  - Offer usage confirmation

---

## 7. LIMITS & OFFLINE

### Usage Limits (NOT VERIFIED)
- No confirmed daily or per-user caps

### Offline Usage (NOT VERIFIED)
- No confirmed offline redemption support

---

## 8. PAYMENTS

### Customer Payments (PARTIALLY VERIFIED)
- Subscription required for offer usage
- Renewal reminders present

### Merchant Payments (VERIFIED)
- Monthly subscription required

---

## 9. NON-GOALS
- Offline redemption
- Automated fraud scoring
- Advanced analytics beyond basic dashboards
