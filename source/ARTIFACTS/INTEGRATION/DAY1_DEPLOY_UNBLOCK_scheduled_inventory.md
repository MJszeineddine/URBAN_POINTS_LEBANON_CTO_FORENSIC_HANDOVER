=== PHASE 2: SCHEDULED FUNCTIONS INVENTORY ===
Generated: 2026-01-03T15:25:31+00:00

## Searching for scheduled trigger patterns

src/privacy.ts:273:  .pubsub.schedule('every day 00:00')
src/index.ts:324:  .pubsub.schedule('0 1 * * *')
src/sms.ts:208:  .pubsub.schedule('every 1 hours')
src/subscriptionAutomation.ts:26:  .pubsub.schedule('0 2 * * *') // Every day at 2 AM
src/subscriptionAutomation.ts:193:  .pubsub.schedule('0 10 * * *') // Every day at 10 AM
src/subscriptionAutomation.ts:265:  .pubsub.schedule('0 3 * * *') // Every day at 3 AM
src/subscriptionAutomation.ts:337:  .pubsub.schedule('0 4 * * *') // Every day at 4 AM
src/pushCampaigns.ts:88:  .pubsub.schedule('every 15 minutes')

## Searching for schedule-related exports in index.ts

14: * 6. cleanupExpiredData - Automated data retention
41:export { exportUserData, deleteUserData, cleanupExpiredData } from './privacy';
44:export { sendSMS, verifyOTP, cleanupExpiredOTPs } from './sms';
51:  processSubscriptionRenewals,
53:  cleanupExpiredSubscriptions,
59:  processScheduledCampaigns,
61:  scheduleCampaign,
315: * checkMerchantCompliance - Scheduled function to check merchant monthly quota
324:  .pubsub.schedule('0 1 * * *')
