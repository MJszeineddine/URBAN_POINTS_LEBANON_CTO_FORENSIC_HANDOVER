# Requirements and Flows (Evidence-Based Freeze)

This document is derived strictly from the existing code artifacts and routes in the repository. It enumerates roles, screens, routes, and backend endpoints to serve as a source-of-truth for staging without guessing.

## Roles
- Customer: Mobile app flows inferred from [source/apps/mobile-customer/lib](source/apps/mobile-customer/lib)
- Merchant: Mobile app flows inferred from [source/apps/mobile-merchant/lib](source/apps/mobile-merchant/lib)
- Admin: Web admin flows inferred from [source/apps/web-admin/pages](source/apps/web-admin/pages)

## Customer App
- Entrypoint: [source/apps/mobile-customer/lib/main.dart](source/apps/mobile-customer/lib/main.dart)
- Screens:
  - [favorites_screen.dart](source/apps/mobile-customer/lib/screens/favorites_screen.dart)
  - [settings_screen.dart](source/apps/mobile-customer/lib/screens/settings_screen.dart)
  - [points_history_screen.dart](source/apps/mobile-customer/lib/screens/points_history_screen.dart)
  - [qr_generation_screen.dart](source/apps/mobile-customer/lib/screens/qr_generation_screen.dart)
  - [notifications_screen.dart](source/apps/mobile-customer/lib/screens/notifications_screen.dart)
  - [profile_screen.dart](source/apps/mobile-customer/lib/screens/profile_screen.dart)
  - [offers_list_screen.dart](source/apps/mobile-customer/lib/screens/offers_list_screen.dart)
  - [offer_detail_screen.dart](source/apps/mobile-customer/lib/screens/offer_detail_screen.dart)
  - [edit_profile_screen.dart](source/apps/mobile-customer/lib/screens/edit_profile_screen.dart)
- Services and data:
  - [auth_service.dart](source/apps/mobile-customer/lib/services/auth_service.dart)
  - [fcm_service.dart](source/apps/mobile-customer/lib/services/fcm_service.dart)
  - [stripe_client.dart](source/apps/mobile-customer/lib/services/stripe_client.dart)
  - [offers_repository.dart](source/apps/mobile-customer/lib/services/offers_repository.dart)
  - [onboarding_service.dart](source/apps/mobile-customer/lib/services/onboarding_service.dart)
  - [location_service.dart](source/apps/mobile-customer/lib/services/location_service.dart)
  - Models: [customer.dart](source/apps/mobile-customer/lib/models/customer.dart), [offer.dart](source/apps/mobile-customer/lib/models/offer.dart), [location.dart](source/apps/mobile-customer/lib/models/location.dart), [merchant.dart](source/apps/mobile-customer/lib/models/merchant.dart)

## Merchant App
- Entrypoint: [source/apps/mobile-merchant/lib/main.dart](source/apps/mobile-merchant/lib/main.dart)
- Screens:
  - [profile_edit_screen.dart](source/apps/mobile-merchant/lib/screens/profile_edit_screen.dart)
  - [edit_offer_screen.dart](source/apps/mobile-merchant/lib/screens/edit_offer_screen.dart)
  - [redemption_history_screen.dart](source/apps/mobile-merchant/lib/screens/redemption_history_screen.dart)
  - [create_offer_screen.dart](source/apps/mobile-merchant/lib/screens/create_offer_screen.dart)
  - [validate_redemption_screen.dart](source/apps/mobile-merchant/lib/screens/validate_redemption_screen.dart)
  - [merchant_analytics_screen.dart](source/apps/mobile-merchant/lib/screens/merchant_analytics_screen.dart)
  - [offer_creation_screen.dart](source/apps/mobile-merchant/lib/screens/offer_creation_screen.dart)
  - [my_offers_screen.dart](source/apps/mobile-merchant/lib/screens/my_offers_screen.dart)
  - [subscription_screen.dart](source/apps/mobile-merchant/lib/screens/subscription_screen.dart)
  - [qr_scanner_screen.dart](source/apps/mobile-merchant/lib/screens/qr_scanner_screen.dart)
  - [staff_management_screen.dart](source/apps/mobile-merchant/lib/screens/staff_management_screen.dart)
  - [redemption_approval_screen.dart](source/apps/mobile-merchant/lib/screens/redemption_approval_screen.dart)
- Services and data:
  - [auth_service.dart](source/apps/mobile-merchant/lib/services/auth_service.dart)
  - [staff_service.dart](source/apps/mobile-merchant/lib/services/staff_service.dart)
  - [offer_service.dart](source/apps/mobile-merchant/lib/services/offer_service.dart)
  - [redemption_service.dart](source/apps/mobile-merchant/lib/services/redemption_service.dart)
  - [merchant_service.dart](source/apps/mobile-merchant/lib/services/merchant_service.dart)
  - [subscription_service.dart](source/apps/mobile-merchant/lib/services/subscription_service.dart)
  - [stripe_client.dart](source/apps/mobile-merchant/lib/services/stripe_client.dart)
  - [onboarding_service.dart](source/apps/mobile-merchant/lib/services/onboarding_service.dart)
  - [fcm_service.dart](source/apps/mobile-merchant/lib/services/fcm_service.dart)
  - State: [billing_state.dart](source/apps/mobile-merchant/lib/services/billing_state.dart)
  - Models: [customer.dart](source/apps/mobile-merchant/lib/models/customer.dart), [offer.dart](source/apps/mobile-merchant/lib/models/offer.dart), [merchant.dart](source/apps/mobile-merchant/lib/models/merchant.dart)

## Web Admin
- Pages and app shell: [source/apps/web-admin/pages](source/apps/web-admin/pages)
- Key pages:
  - [admin/login.tsx](source/apps/web-admin/pages/admin/login.tsx)
  - [admin/dashboard.tsx](source/apps/web-admin/pages/admin/dashboard.tsx)
  - [admin/compliance.tsx](source/apps/web-admin/pages/admin/compliance.tsx)
  - [admin/merchants.tsx](source/apps/web-admin/pages/admin/merchants.tsx)
  - [admin/users.tsx](source/apps/web-admin/pages/admin/users.tsx)
  - [admin/offers.tsx](source/apps/web-admin/pages/admin/offers.tsx)
  - [admin/payments.tsx](source/apps/web-admin/pages/admin/payments.tsx)
  - [admin/points.tsx](source/apps/web-admin/pages/admin/points.tsx)
  - [admin/analytics.tsx](source/apps/web-admin/pages/admin/analytics.tsx)
  - [admin/diagnostics.tsx](source/apps/web-admin/pages/admin/diagnostics.tsx)
  - [admin/fraud.tsx](source/apps/web-admin/pages/admin/fraud.tsx)
  - [admin/audit-logs.tsx](source/apps/web-admin/pages/admin/audit-logs.tsx)

## REST API Endpoints
Derived from [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts):
- GET /
- GET /api/health
- GET /api/feature-flags
- POST /api/auth/register
- POST /api/auth/login
- GET /api/users/me
- GET /api/users/me/vouchers
- GET /api/users/me/transactions
- GET /api/merchants
- GET /api/merchants/:id
- GET /api/merchants/:id/offers
- GET /api/offers
- GET /api/offers/:id
- POST /api/offers/:id/purchase
- POST /api/vouchers/:id/validate
- POST /api/vouchers/:id/redeem
- POST /api/vouchers/:id/gift
- GET /api/gifts/received
- POST /api/gifts/:id/accept
- POST /api/gifts/:id/reject

## Firebase Functions (Selected Modules)
From [source/backend/firebase-functions/src](source/backend/firebase-functions/src):
- Core: [index.ts](source/backend/firebase-functions/src/index.ts), [auth.ts](source/backend/firebase-functions/src/auth.ts)
- Notifications: [phase3Notifications.ts](source/backend/firebase-functions/src/phase3Notifications.ts), [fcm.ts](source/backend/firebase-functions/src/fcm.ts)
- Scheduling: [phase3Scheduler.ts](source/backend/firebase-functions/src/phase3Scheduler.ts), [scheduled_disabled.ts](source/backend/firebase-functions/src/scheduled_disabled.ts)
- Webhooks: [webhooks/stripe.ts](source/backend/firebase-functions/src/webhooks/stripe.ts), [paymentWebhooks.ts](source/backend/firebase-functions/src/paymentWebhooks.ts)
- Messaging: [whatsapp.ts](source/backend/firebase-functions/src/whatsapp.ts), [sms.ts](source/backend/firebase-functions/src/sms.ts)
- Admin and Monitoring: [adminModeration.ts](source/backend/firebase-functions/src/adminModeration.ts), [monitoring.ts](source/backend/firebase-functions/src/monitoring.ts), [logger.ts](source/backend/firebase-functions/src/logger.ts)

## Environment Requirements (Detected from Code)
REST API ([server.ts](source/backend/rest-api/src/server.ts), [database.ts](source/backend/rest-api/src/config/database.ts)):
- `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGIN`, `API_RATE_LIMIT_WINDOW_MS`, `API_RATE_LIMIT_MAX_REQUESTS`, `PORT`

Firebase Functions ([index.ts](source/backend/firebase-functions/src/index.ts), [webhooks/stripe.ts](source/backend/firebase-functions/src/webhooks/stripe.ts), [monitoring.ts](source/backend/firebase-functions/src/monitoring.ts), [whatsapp.ts](source/backend/firebase-functions/src/whatsapp.ts)):
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `SENTRY_DSN`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `WHATSAPP_NUMBER`, `QR_TOKEN_SECRET`
- Emulator-related: `FUNCTIONS_EMULATOR`, `FIRESTORE_EMULATOR_HOST`, `GCLOUD_PROJECT`, `GOOGLE_CLOUD_PROJECT`
- Runtime config references present via `functions.config()` (requires Firebase Functions config in staging)

Web Admin:
- Pages are present under [pages](source/apps/web-admin/pages). No explicit `NEXT_PUBLIC_*` variables detected in page code during scan.

## High-Level Flows (Inferred from Screens and Endpoints)
- Customer:
  - Discover and view offers → [offers_list_screen.dart](source/apps/mobile-customer/lib/screens/offers_list_screen.dart), [offer_detail_screen.dart](source/apps/mobile-customer/lib/screens/offer_detail_screen.dart)
  - Purchase and manage vouchers → REST endpoints under `/api/offers/:id/purchase`, `/api/vouchers/*`
  - Profile and settings → [profile_screen.dart](source/apps/mobile-customer/lib/screens/profile_screen.dart), [settings_screen.dart](source/apps/mobile-customer/lib/screens/settings_screen.dart)
  - Points history and QR generation → [points_history_screen.dart](source/apps/mobile-customer/lib/screens/points_history_screen.dart), [qr_generation_screen.dart](source/apps/mobile-customer/lib/screens/qr_generation_screen.dart)
  - Notifications and favorites → [notifications_screen.dart](source/apps/mobile-customer/lib/screens/notifications_screen.dart), [favorites_screen.dart](source/apps/mobile-customer/lib/screens/favorites_screen.dart)

- Merchant:
  - Offer management → [create_offer_screen.dart](source/apps/mobile-merchant/lib/screens/create_offer_screen.dart), [edit_offer_screen.dart](source/apps/mobile-merchant/lib/screens/edit_offer_screen.dart), [my_offers_screen.dart](source/apps/mobile-merchant/lib/screens/my_offers_screen.dart)
  - Redemption validation and approvals → [validate_redemption_screen.dart](source/apps/mobile-merchant/lib/screens/validate_redemption_screen.dart), [redemption_approval_screen.dart](source/apps/mobile-merchant/lib/screens/redemption_approval_screen.dart), [redemption_history_screen.dart](source/apps/mobile-merchant/lib/screens/redemption_history_screen.dart)
  - Staff and subscription → [staff_management_screen.dart](source/apps/mobile-merchant/lib/screens/staff_management_screen.dart), [subscription_screen.dart](source/apps/mobile-merchant/lib/screens/subscription_screen.dart)
  - Analytics and QR → [merchant_analytics_screen.dart](source/apps/mobile-merchant/lib/screens/merchant_analytics_screen.dart), [qr_scanner_screen.dart](source/apps/mobile-merchant/lib/screens/qr_scanner_screen.dart)

- Admin:
  - Authentication and dashboard → [admin/login.tsx](source/apps/web-admin/pages/admin/login.tsx), [admin/dashboard.tsx](source/apps/web-admin/pages/admin/dashboard.tsx)
  - Entities and operations → merchants, users, offers, payments, points, analytics, diagnostics, fraud, audit logs under [source/apps/web-admin/pages/admin](source/apps/web-admin/pages/admin)

## Notes
- This freeze is strictly anchored to code paths and endpoints found. Any staging gate execution must validate environment variables and Firebase Functions runtime config as listed above.
