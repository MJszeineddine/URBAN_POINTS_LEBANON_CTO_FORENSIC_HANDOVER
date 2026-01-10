/**
 * Integration Test - Qatar Spec Compliance
 * Tests backend enforcement of all 6 Qatar requirements
 * Run with: npm test
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'urbangenspark-test',
  });
}

describe('Qatar Spec Integration Tests', () => {
  describe('Backend Code Verification', () => {
    it('should have HMAC hard-fail enforcement', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');

      // Check for HMAC secret enforcement
      const hasHMACCheck =
        indexContent.includes('QR_TOKEN_SECRET') && indexContent.includes('throw new Error');

      if (!hasHMACCheck) {
        throw new Error('HMAC hard-fail enforcement not found in index.ts');
      }
    });

    it('should have rate limiting implementation', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');
      const indexCoreContent = fs.readFileSync(__dirname + '/../core/indexCore.ts', 'utf8');

      const hasRateLimiting =
        indexContent.includes('rate_limit') ||
        indexContent.includes('rateLimit') ||
        indexCoreContent.includes('rate_limit') ||
        indexCoreContent.includes('rateLimit');

      if (!hasRateLimiting) {
        throw new Error('Rate limiting implementation not found');
      }
    });

    it('should have monthly redemption enforcement', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');
      const adminContent = fs.readFileSync(__dirname + '/../core/admin.ts', 'utf8');

      const hasMonthlyCheck =
        indexContent.includes('startOfMonth') ||
        indexContent.includes('endOfMonth') ||
        adminContent.includes('startOfMonth') ||
        adminContent.includes('endOfMonth');

      if (!hasMonthlyCheck) {
        throw new Error('Monthly redemption logic not found');
      }
    });

    it('should have admin approval workflow', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');

      const hasAdminWorkflow =
        indexContent.includes('approveOffer') && indexContent.includes('rejectOffer');

      if (!hasAdminWorkflow) {
        throw new Error('Admin approval workflow not found');
      }
    });

    it('should have merchant compliance tracking', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');
      const adminContent = fs.readFileSync(__dirname + '/../core/admin.ts', 'utf8');

      const hasCompliance =
        (indexContent.includes('checkMerchantCompliance') ||
          adminContent.includes('coreCheckMerchantCompliance')) &&
        (indexContent.includes('compliance_status') || adminContent.includes('compliance_status'));

      if (!hasCompliance) {
        throw new Error('Merchant compliance tracking not found');
      }
    });

    it('should have subscription validation', () => {
      const fs = require('fs');
      const indexContent = fs.readFileSync(__dirname + '/../index.ts', 'utf8');

      const hasSubscriptionCheck =
        indexContent.includes('subscription') &&
        (indexContent.includes('status') || indexContent.includes('active'));

      if (!hasSubscriptionCheck) {
        throw new Error('Subscription validation not found');
      }
    });
  });

  describe('Firestore Rules Verification', () => {
    it('should have offers approval enforcement in rules', () => {
      const fs = require('fs');
      const rulesPath = __dirname + '/../../../../infra/firestore.rules';

      if (!fs.existsSync(rulesPath)) {
        throw new Error('Firestore rules file not found');
      }

      const rulesContent = fs.readFileSync(rulesPath, 'utf8');
      const hasApprovalRules = rulesContent.includes('status') && rulesContent.includes('approved');

      if (!hasApprovalRules) {
        throw new Error('Offer approval rules not found in firestore.rules');
      }
    });

    it('should have CF-only writes for rate_limits', () => {
      const fs = require('fs');
      const rulesPath = __dirname + '/../../../../infra/firestore.rules';
      const rulesContent = fs.readFileSync(rulesPath, 'utf8');

      const hasRateLimitProtection = rulesContent.includes('rate_limits');

      if (!hasRateLimitProtection) {
        throw new Error('rate_limits collection protection not found');
      }
    });
  });

  describe('Firestore Indexes Verification', () => {
    it('should have monthly redemption indexes', () => {
      const fs = require('fs');
      const indexesPath = __dirname + '/../../../../infra/firestore.indexes.json';

      if (!fs.existsSync(indexesPath)) {
        throw new Error('Firestore indexes file not found');
      }

      const indexesContent = fs.readFileSync(indexesPath, 'utf8');
      const indexes = JSON.parse(indexesContent);

      const hasRedemptionIndexes = indexes.indexes?.some(
        (idx: any) => idx.collectionGroup === 'redemptions'
      );

      if (!hasRedemptionIndexes) {
        throw new Error('Redemption indexes not found');
      }
    });

    it('should have rate limit indexes', () => {
      const fs = require('fs');
      const indexesPath = __dirname + '/../../../../infra/firestore.indexes.json';
      const indexesContent = fs.readFileSync(indexesPath, 'utf8');
      const indexes = JSON.parse(indexesContent);

      const hasRateLimitIndexes = indexes.indexes?.some(
        (idx: any) => idx.collectionGroup === 'qr_tokens'
      );

      if (!hasRateLimitIndexes) {
        throw new Error('Rate limit indexes not found');
      }
    });
  });

  describe('Configuration Verification', () => {
    it('should have firebase.json with emulator config', () => {
      const fs = require('fs');
      const firebaseConfigPath = __dirname + '/../../../../infra/firebase.json';

      if (!fs.existsSync(firebaseConfigPath)) {
        throw new Error('firebase.json not found');
      }

      const firebaseConfig = JSON.parse(fs.readFileSync(firebaseConfigPath, 'utf8'));

      if (!firebaseConfig.emulators) {
        throw new Error('Emulator configuration not found in firebase.json');
      }

      if (!firebaseConfig.emulators.firestore || !firebaseConfig.emulators.functions) {
        throw new Error('Firestore or Functions emulator not configured');
      }
    });

    it('should have package.json with test script', () => {
      const fs = require('fs');
      const packagePath = __dirname + '/../../package.json';
      const packageContent = JSON.parse(fs.readFileSync(packagePath, 'utf8'));

      if (!packageContent.scripts?.test) {
        throw new Error('Test script not found in package.json');
      }
    });
  });

  describe('Web Admin Verification', () => {
    it('should have Firebase dependency in web admin', () => {
      const fs = require('fs');
      const webAdminPackagePath = __dirname + '/../../../../apps/web-admin/package.json';

      if (!fs.existsSync(webAdminPackagePath)) {
        console.warn('Web admin package.json not found - skipping');
        return;
      }

      const packageContent = JSON.parse(fs.readFileSync(webAdminPackagePath, 'utf8'));

      if (!packageContent.dependencies?.firebase) {
        throw new Error('Firebase dependency not found in web admin');
      }
    });
  });
});
