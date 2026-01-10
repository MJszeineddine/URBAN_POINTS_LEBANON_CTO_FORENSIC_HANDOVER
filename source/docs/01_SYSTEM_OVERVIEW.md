# Urban Points Lebanon - System Overview

## What is Urban Points Lebanon?

Urban Points Lebanon is a **comprehensive loyalty and offers ecosystem** connecting consumers, merchants, and administrators in Lebanon. The platform enables:

- **Consumers** to discover deals, earn points, redeem offers, and track their loyalty rewards
- **Merchants** to create promotional offers, manage redemptions, and analyze customer engagement
- **Administrators** to oversee the platform, approve merchants/offers, and monitor system health

---

## Core Value Proposition

### For Consumers
- **Discover** local offers and deals from nearby merchants
- **Earn** points through purchases and referrals
- **Redeem** exclusive offers using secure QR codes
- **Track** points balance and transaction history
- **Unlock** premium benefits through subscription tiers (Silver/Gold)

### For Merchants
- **Create** promotional offers to attract customers
- **Validate** redemptions with secure QR scanning
- **Analyze** customer engagement and offer performance
- **Manage** multiple branch locations
- **Access** premium features for enhanced visibility

### For Platform Administrators
- **Approve** merchant registrations and offer submissions
- **Monitor** system-wide metrics and performance
- **Moderate** content and enforce platform policies
- **Configure** system settings and features
- **Generate** analytics and business intelligence reports

---

## User Types and Roles

### 1. Customer (Consumer)
**Primary Activities:**
- Browse available offers by category, location, or merchant
- Scan QR codes to redeem offers at merchant locations
- View points balance and transaction history
- Refer friends to earn bonus points
- Purchase premium subscriptions for enhanced benefits
- Manage account settings and preferences

**Account Features:**
- Email/phone authentication
- Profile management (name, photo, preferences)
- Points wallet
- Favorites list
- Notification preferences
- Referral code

### 2. Merchant (Business Owner)
**Primary Activities:**
- Create and manage promotional offers
- Define offer terms (discount %, min spend, validity period)
- Scan customer QR codes to validate redemptions
- View analytics dashboard (redemption counts, top offers, revenue impact)
- Manage business profile and branch locations
- Respond to customer reviews

**Account Features:**
- Business profile (logo, description, category, contact info)
- Multi-location support (branches)
- Offer creation wizard
- Analytics dashboard
- Redemption history
- Premium subscription for featured placement

### 3. Admin (Platform Operator)
**Primary Activities:**
- Review and approve merchant registrations
- Moderate offer submissions for policy compliance
- Monitor platform health and usage metrics
- Handle customer support escalations
- Configure system parameters (points values, subscription pricing)
- Generate business intelligence reports

**Account Features:**
- Full system access
- Merchant approval workflow
- Offer moderation tools
- System configuration panel
- Advanced analytics
- User management

---

## Main Domain Flows

### 1. Offer Discovery Flow
```
Customer opens app
  → Views curated offers feed (nearby, trending, categories)
  → Filters by category, location, discount
  → Views offer details (description, terms, merchant info)
  → Saves offer to favorites (optional)
  → Proceeds to merchant location
```

### 2. Offer Redemption Flow
```
Customer at merchant location
  → Opens saved/selected offer
  → Clicks "Redeem Now"
  → System generates secure QR token (60-second validity)
  → Merchant scans QR code
  → System validates token (authentication, expiry, eligibility)
  → Points deducted from customer wallet
  → Offer marked as redeemed
  → Both parties receive confirmation
```

### 3. Points Earning Flow
```
Customer earns points through:
  
  a) Purchases:
     Customer redeems offer → Points deducted → Transaction recorded
  
  b) Referrals:
     Customer shares referral code → Friend signs up using code
     → Referrer earns 500 points → Referee earns 100 points
  
  c) Promotions:
     Admin runs point bonus campaign → Eligible customers receive bonus
```

### 4. Offer Creation Flow (Merchant)
```
Merchant logs in
  → Navigates to "Create Offer"
  → Fills offer form:
     - Title and description
     - Discount percentage
     - Minimum spend requirement
     - Validity period (start/end dates)
     - Maximum redemptions
     - Target customer segment (optional)
  → Submits offer for review
  → Admin reviews and approves/rejects
  → Approved offer appears in customer app
```

### 5. Merchant Approval Flow (Admin)
```
New merchant registers
  → System flags account for admin review
  → Admin reviews:
     - Business documentation
     - Contact information
     - Compliance with platform policies
  → Admin approves/rejects registration
  → Merchant receives notification
  → Approved merchants can create offers
```

---

## Key Business Rules

### Points Economy
- **Referrer Bonus**: 500 points per successful referral
- **Referee Bonus**: 100 points for using referral code
- **Point Expiry**: Points do not expire (configurable)
- **Minimum Redemption**: Defined per offer (typically 100-500 points)

### Offer Redemption Rules
1. **One Redemption Per Customer Per Offer**: Each customer can redeem a specific offer only once
2. **Points Requirement**: Customer must have sufficient points in wallet
3. **Premium Requirement**: Some offers require Silver/Gold subscription
4. **Geographic Restriction**: Offers may be limited to specific locations
5. **Time Validity**: Offer must be within its validity period
6. **Max Redemptions**: Offer deactivates after reaching max redemption count
7. **Merchant Status**: Merchant must be approved and active
8. **Customer Status**: Customer account must be active and verified

### Subscription Tiers
- **Free**: Basic access, standard offers, limited features
- **Silver** ($4.99/month): Priority support, exclusive offers, 10% bonus points
- **Gold** ($9.99/month): All Silver benefits + premium offers, 20% bonus points, early access

### QR Security
- **Token Expiry**: 60 seconds after generation
- **Device Binding**: Token tied to specific device hash
- **Single Use**: Token invalidated after successful scan
- **HMAC Signature**: Cryptographic verification prevents tampering

---

## Technology Stack Summary

### Backend
- **Firebase Cloud Functions**: Serverless business logic (Node.js/TypeScript)
- **Firestore**: NoSQL database for real-time data sync
- **Firebase Auth**: User authentication and session management
- **REST API**: Express.js API for backward compatibility (PostgreSQL)

### Mobile Apps (Customer, Merchant, Admin)
- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Storage**: Hive (local), Firestore (cloud)
- **Push Notifications**: Firebase Cloud Messaging (FCM)

### Web Applications
- **Admin Dashboard**: Static HTML/CSS/JavaScript (lightweight)
- **Landing Site**: Static website (hosted on Firebase Hosting)

### Infrastructure
- **Hosting**: Firebase Hosting (web apps)
- **Functions**: Firebase Cloud Functions (us-central1)
- **Database**: Firestore (multi-region)
- **Authentication**: Firebase Auth
- **Storage**: Firebase Cloud Storage (media/images)
- **Analytics**: Firebase Analytics + Custom dashboard

---

## System Architecture Highlights

### Data Flow
```
Mobile/Web Client
  ↓ HTTPS
Firebase Auth (Authentication)
  ↓ Authenticated Requests
Cloud Functions (Business Logic)
  ↓ Firestore SDK
Firestore Database (Data Storage)
  ↓ Real-time Sync
Mobile/Web Client (Live Updates)
```

### Security Layers
1. **Authentication**: Firebase Auth with email/phone + password/OTP
2. **Authorization**: Firestore Security Rules for role-based access
3. **Data Validation**: Cloud Functions validate all writes
4. **QR Security**: HMAC-signed tokens with device binding
5. **Rate Limiting**: Prevent abuse of API endpoints
6. **Encryption**: All data encrypted in transit (TLS) and at rest

---

## Scalability Considerations

- **Serverless Architecture**: Auto-scales with demand (Cloud Functions)
- **NoSQL Database**: Horizontal scalability (Firestore)
- **Regional Deployment**: Multi-region Firestore for low latency
- **CDN Integration**: Firebase Hosting with global CDN
- **Caching Strategy**: Client-side caching for static data
- **Query Optimization**: Composite indexes for common queries

---

## Future Enhancements (Roadmap)

1. **Social Features**: Customer reviews, ratings, merchant responses
2. **Gamification**: Badges, achievements, leaderboards
3. **Advanced Analytics**: Machine learning for personalized offers
4. **Multi-language**: Full Arabic localization
5. **Payment Integration**: Direct payment processing (OMT, Whish Money, Stripe)
6. **Loyalty Tiers**: Dynamic tier progression based on activity
7. **Merchant CRM**: Customer relationship management tools
8. **Geo-fencing**: Automatic offer notifications based on location
9. **Social Sharing**: Share favorite offers on social media
10. **API Marketplace**: Third-party integrations for merchants

---

## Support and Resources

- **Customer Support**: In-app help, FAQ, email support
- **Merchant Onboarding**: Dedicated onboarding flow with documentation
- **Admin Training**: Internal documentation and training materials
- **Developer Docs**: API documentation, integration guides
- **Community**: Merchant community forums (planned)

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Target Audience**: Developers, stakeholders, new team members
