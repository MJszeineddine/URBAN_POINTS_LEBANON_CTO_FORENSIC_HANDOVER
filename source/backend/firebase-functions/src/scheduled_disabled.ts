/**
 * SCHEDULED FUNCTIONS - TEMPORARILY DISABLED
 * 
 * These functions require Cloud Scheduler API to be enabled.
 * To enable: https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com
 * 
 * Once enabled, import and export these from index.ts
 */

// Re-export scheduled functions from their modules
// These are NOT exported by default to prevent deployment blocker

export { cleanupExpiredData } from './privacy';
export { cleanupExpiredOTPs } from './sms';
export {
  processSubscriptionRenewals,
  cleanupExpiredSubscriptions,
} from './subscriptionAutomation';
export {
  processScheduledCampaigns,
} from './pushCampaigns';

// checkMerchantCompliance is defined inline in index.ts
// Export placeholder to document it exists
export const checkMerchantComplianceScheduled = null;

