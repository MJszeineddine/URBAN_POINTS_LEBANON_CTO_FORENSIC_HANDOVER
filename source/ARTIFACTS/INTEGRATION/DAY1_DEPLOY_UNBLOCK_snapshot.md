# DAY 1 DEPLOYMENT UNBLOCK - INITIAL STATE SNAPSHOT

**Generated**: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

## Git Status
On branch main
Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
  (commit or discard the untracked or modified content in submodules)
	deleted:    BLOCKERS.md
	deleted:    REPORT.md
	modified:   apps/mobile-customer/macos/Flutter/GeneratedPluginRegistrant.swift
	modified:   apps/mobile-customer/pubspec.lock
	modified:   apps/mobile-customer/pubspec.yaml
	modified:   apps/mobile-customer/test/widget_test.dart
	modified:   apps/mobile-merchant/macos/Flutter/GeneratedPluginRegistrant.swift
	modified:   apps/mobile-merchant/pubspec.lock
	modified:   apps/mobile-merchant/pubspec.yaml
	modified:   apps/mobile-merchant/test/widget_test.dart
	modified:   apps/web-admin/_headers
	modified:   apps/web-admin/headers.conf
	modified:   apps/web-admin/index.html
	modified:   apps/web-admin/package.json
	modified:   apps/web-admin/vercel.json
	deleted:    archive/urban-points-lebanon-complete
	deleted:    archive/urban_points_lebanon_customer_v2
	modified:   backend/firebase-functions (modified content, untracked content)
	modified:   infra/firebase.json
	modified:   infra/firestore.indexes.json
	modified:   infra/firestore.rules

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.firebaserc
	.github/
	ARTIFACTS/
	apps/web-admin/.next/
	docs/PRODUCTION_CONFIG.md
	firebase.json
	release_gate.sh
	scripts/backup_firestore.sh
	scripts/restore_firestore.sh
	tools/

no changes added to commit (use "git add" and/or "git commit -a")

## Firebase Configuration Files

### Root firebase.json
```json
{
  "projects": {
    "default": "urbangenspark",
    "dev": "urbanpoints-lebanon-dev",
    "staging": "urbanpoints-lebanon-staging",
    "prod": "urbangenspark"
  },
  "targets": {
    "urbangenspark": {
      "hosting": {
        "web-admin": [
          "urbanpoints-web-admin-prod"
        ]
      }
    },
    "urbanpoints-lebanon-staging": {
      "hosting": {
        "web-admin": [
          "urbanpoints-web-admin-staging"
        ]
      }
    },
    "urbanpoints-lebanon-dev": {
      "hosting": {
        "web-admin": [
          "urbanpoints-web-admin-dev"
        ]
      }
    }
  }
}
```

### Functions Trigger Inventory

Searching for scheduled triggers...
backend/firebase-functions/src/privacy.ts:  .pubsub.schedule('every day 00:00')
backend/firebase-functions/src/index.ts:  .pubsub.schedule('0 1 * * *')
backend/firebase-functions/src/sms.ts:  .pubsub.schedule('every 1 hours')
backend/firebase-functions/src/subscriptionAutomation.ts:  .pubsub.schedule('0 2 * * *') // Every day at 2 AM
backend/firebase-functions/src/subscriptionAutomation.ts:  .pubsub.schedule('0 10 * * *') // Every day at 10 AM
backend/firebase-functions/src/subscriptionAutomation.ts:  .pubsub.schedule('0 3 * * *') // Every day at 3 AM
backend/firebase-functions/src/subscriptionAutomation.ts:  .pubsub.schedule('0 4 * * *') // Every day at 4 AM
backend/firebase-functions/src/pushCampaigns.ts:  .pubsub.schedule('every 15 minutes')
