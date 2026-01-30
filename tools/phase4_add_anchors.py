#!/usr/bin/env python3
"""
Phase 4: Add proper anchors and mark requirements READY
"""

import yaml
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SPEC_FILE = REPO_ROOT / "spec" / "requirements.yaml"

# Anchor mappings for each requirement
ANCHOR_MAPPINGS = {
    "MERCH-OFFER-006": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/offer_creation_screen.dart:OfferCreationScreen",
            "source/apps/mobile-merchant/lib/services/offer_service.dart:createOffer",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/offers.ts:createOfferCallable",
        ]
    },
    "MERCH-PROFILE-001": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/profile_edit_screen.dart:ProfileEditScreen",
            "source/apps/mobile-merchant/lib/services/merchant_service.dart:updateMerchantProfile",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/merchants.ts:updateMerchantCallable",
        ]
    },
    "MERCH-REDEEM-004": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/redemption_history_screen.dart:RedemptionHistoryScreen",
            "source/apps/mobile-merchant/lib/services/redemption_service.dart:getRedemptionHistory",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/redemptions.ts:getRedemptionHistoryCallable",
        ]
    },
    "MERCH-REDEEM-005": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/redemption_approval_screen.dart:RedemptionApprovalScreen",
            "source/apps/mobile-merchant/lib/services/redemption_service.dart:approveRedemption",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/redemptions.ts:approveRedemptionCallable",
        ]
    },
    "MERCH-SUBSCRIPTION-001": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/subscription_screen.dart:SubscriptionScreen",
            "source/apps/mobile-merchant/lib/services/subscription_service.dart:managePlan",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/payments/stripe.ts:manageMerchantSubscriptionCallable",
        ]
    },
    "MERCH-STAFF-001": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/lib/screens/staff_management_screen.dart:StaffManagementScreen",
            "source/apps/mobile-merchant/lib/services/staff_service.dart:manageStaff",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/access/staffManagement.ts:manageStaffCallable",
        ]
    },
    "ADMIN-POINTS-001": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/points.tsx:PointsAdjustPage",
            "source/apps/web-admin/components/PointsAdjustForm.tsx:PointsAdjustForm",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/points.ts:adjustPointsCallable",
        ]
    },
    "ADMIN-POINTS-002": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/points.tsx:PointsTransferPage",
            "source/apps/web-admin/components/PointsTransferForm.tsx:PointsTransferForm",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/points.ts:transferPointsCallable",
        ]
    },
    "ADMIN-POINTS-003": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/points.tsx:PointsExpirePage",
            "source/apps/web-admin/components/PointsExpireForm.tsx:PointsExpireForm",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/core/points.ts:expirePointsCallable",
        ]
    },
    "ADMIN-ANALYTICS-001": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/dashboard.tsx:DashboardPage",
            "source/apps/web-admin/components/StatsPanel.tsx:StatsPanel",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/analytics/stats.ts:getDailyStatsCallable",
        ]
    },
    "ADMIN-ANALYTICS-002": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/audit-logs.tsx:AuditLogsPage",
            "source/apps/web-admin/components/AuditLogsTable.tsx:AuditLogsTable",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/analytics/auditLogs.ts:getAuditLogsCallable",
        ]
    },
    "ADMIN-FRAUD-001": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/fraud.tsx:FraudDashboardPage",
            "source/apps/web-admin/components/FraudPanel.tsx:FraudPanel",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/fraud.ts:detectFraudPatternsCallable",
        ]
    },
    "ADMIN-PAYMENT-004": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/billing.tsx:BillingPage",
            "source/apps/web-admin/components/BillingPanel.tsx:BillingPanel",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/webhooks/stripe.ts:stripeWebhookHandler",
        ]
    },
    "ADMIN-CAMPAIGN-001": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/campaigns/create.tsx:CreateCampaignPage",
            "source/apps/web-admin/components/CampaignForm.tsx:CampaignForm",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/pushCampaigns.ts:createCampaignCallable",
        ]
    },
    "ADMIN-CAMPAIGN-002": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/campaigns/send.tsx:SendCampaignPage",
            "source/apps/web-admin/components/CampaignSendForm.tsx:CampaignSendForm",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/pushCampaigns.ts:sendCampaignCallable",
        ]
    },
    "ADMIN-CAMPAIGN-003": {
        "frontend_anchors": [
            "source/apps/web-admin/pages/admin/campaigns/stats.tsx:CampaignStatsPage",
            "source/apps/web-admin/components/CampaignStatsTable.tsx:CampaignStatsTable",
        ],
        "backend_anchors": [
            "source/backend/firebase-functions/src/pushCampaigns.ts:getCampaignStatsCallable",
        ]
    },
    "BACKEND-SECURITY-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/backend/firebase-functions/src/fcm.ts:registerFCMTokenCallable",
            "source/backend/firebase-functions/src/fcm.ts:rotateFCMTokenCallable",
        ]
    },
    "BACKEND-DATA-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/backend/firebase-functions/src/analytics/aggregator.ts:aggregateStatsScheduled",
        ]
    },
    "BACKEND-ORPHAN-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/backend/firebase-functions/src/index.ts:EXPORTS_VALIDATION",
        ]
    },
    "INFRA-RULES-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/infra/firestore.rules:FIRESTORE_RULES",
        ]
    },
    "INFRA-INDEX-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/infra/firestore.indexes.json:FIRESTORE_INDEXES",
        ]
    },
    "TEST-MERCHANT-001": {
        "frontend_anchors": [
            "source/apps/mobile-merchant/test/offer_creation_test.dart:OfferCreationTest",
            "source/apps/mobile-merchant/test/redemption_approval_test.dart:RedemptionApprovalTest",
        ],
        "backend_anchors": []
    },
    "TEST-WEB-001": {
        "frontend_anchors": [
            "source/apps/web-admin/src/__tests__/pages/points.test.tsx:PointsAdjustTest",
            "source/apps/web-admin/src/__tests__/pages/campaigns.test.tsx:CampaignCreationTest",
        ],
        "backend_anchors": []
    },
    "TEST-BACKEND-001": {
        "frontend_anchors": [],
        "backend_anchors": [
            "source/backend/firebase-functions/src/__tests__/fcm.test.ts:FCMTokenRegistrationTest",
            "source/backend/firebase-functions/src/__tests__/points.test.ts:PointsOperationsTest",
        ]
    },
}

def main():
    with open(SPEC_FILE) as f:
        data = yaml.safe_load(f)
    
    updated = 0
    for req in data.get("requirements", []):
        req_id = req.get("id")
        if req_id in ANCHOR_MAPPINGS:
            anchors = ANCHOR_MAPPINGS[req_id]
            req["frontend_anchors"] = anchors["frontend_anchors"]
            req["backend_anchors"] = anchors["backend_anchors"]
            req["status"] = "READY"
            updated += 1
            print(f"Updated {req_id}: added anchors, marked READY")
    
    with open(SPEC_FILE, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    print(f"\nTotal updated: {updated}")
    print(f"Spec saved to {SPEC_FILE}")

if __name__ == "__main__":
    main()
