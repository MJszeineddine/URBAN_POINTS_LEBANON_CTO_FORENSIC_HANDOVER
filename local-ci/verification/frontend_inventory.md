# Frontend Inventory (source-of-truth)

- Customer app (READY): Flutter app init/auth/FCM and tabbed home in [source/apps/mobile-customer/lib/main.dart](source/apps/mobile-customer/lib/main.dart); routes include billing and points history; streams customers/{uid} and active offers.
- Merchant app (READY): Flutter app with dashboard, validate redemption flow, customers list, profile, billing in [source/apps/mobile-merchant/lib/main.dart](source/apps/mobile-merchant/lib/main.dart); AuthValidator enforces merchant role; subscribes to FCM topic all_merchants.
- Admin portal (PARTIAL): Next.js pages for dashboard, users, merchants, offers, diagnostics under [source/apps/web-admin/pages/admin](source/apps/web-admin/pages/admin); AdminGuard expects role=admin claims. Moderation actions (role change, merchant suspend, offer approve/reject) depend on callable functions and Firestore writes that current rules deny.
- Shared dependencies: All UIs rely on Firebase project config in [source/firebase.json](source/firebase.json) and Firestore collections customers, merchants, offers, redemptions, qr_tokens.
- Gaps: Admin portal write operations blocked by Firestore rules and callable signatures; no web hosting config surfaced in repo for admin deployment.
