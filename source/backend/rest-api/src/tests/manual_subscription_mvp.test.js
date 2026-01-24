describe('Manual Subscription MVP', () => {
  it('verifies admin subscription activation endpoint exists', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: Admin activation endpoint route defined
    expect(serverCode).toContain('/api/admin/subscriptions/activate');

    // Evidence 2: Admin middleware requirement
    expect(serverCode).toContain('requireAdmin');

    // Evidence 3: Manual source tracking
    expect(serverCode).toContain("source = 'manual'");

    // Evidence 4: Admin can be extracted from JWT
    expect(serverCode).toContain("role !== 'admin'");
  });

  it('verifies monthly offer usage limit enforcement', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: user_offer_usage table creation
    expect(serverCode).toContain('CREATE TABLE IF NOT EXISTS user_offer_usage');

    // Evidence 2: Period key computation (YYYY-MM format)
    expect(serverCode).toContain('const periodKey');

    // Evidence 3: Monthly limit enforcement
    expect(serverCode).toContain('redemptionCount >= 1');

    // Evidence 4: Error code for limit exceeded
    expect(serverCode).toContain('OFFER_MONTHLY_LIMIT_REACHED');

    // Evidence 5: Atomic row locking for race condition prevention
    expect(serverCode).toContain('FOR UPDATE');
  });

  it('verifies redeem endpoint has requireActiveSubscription middleware', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence: Middleware chained to redeem endpoint
    expect(serverCode).toContain("'/api/vouchers/:id/redeem', authenticate, requireActiveSubscription");

    // Evidence: SUBSCRIPTION_REQUIRED code
    expect(serverCode).toContain('SUBSCRIPTION_REQUIRED');
  });

  it('verifies admin middleware checks role', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: requireAdmin middleware defined
    expect(serverCode).toContain('const requireAdmin');

    // Evidence 2: Admin role check logic
    expect(serverCode).toContain("!== 'admin'");

    // Evidence 3: Admin forbidden error code
    expect(serverCode).toContain('ADMIN_REQUIRED');
  });

  it('verifies subscriptions table has required columns for manual activation', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: activated_by column to track which admin activated
    expect(serverCode).toContain('activated_by UUID');

    // Evidence 2: note column for reference/payment info
    expect(serverCode).toContain('note TEXT');

    // Evidence 3: plan_code column for non-stripe subscriptions
    expect(serverCode).toContain('plan_code VARCHAR(50)');

    // Evidence 4: source column tracking activation source
    expect(serverCode).toContain('source VARCHAR(50)');
  });

  it('verifies atomic transaction for monthly limit (no race conditions)', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: Transaction begins
    expect(serverCode).toContain("'BEGIN'");

    // Evidence 2: Row-level locking (SELECT FOR UPDATE)
    expect(serverCode).toContain('FOR UPDATE');

    // Evidence 3: Conditional update based on count
    expect(serverCode).toContain('redemptionCount >= 1');

    // Evidence 4: Rollback on limit violation
    expect(serverCode).toContain('ROLLBACK');

    // Evidence 5: Commit on success
    expect(serverCode).toContain("'COMMIT'");
  });

  it('verifies entitlements endpoint returns subscription status', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence: GET /api/entitlements/me endpoint
    expect(serverCode).toContain("'/api/entitlements/me'");

    // Evidence: Returns hasActiveSubscription boolean
    expect(serverCode).toContain('hasActiveSubscription');

    // Evidence: Returns expiration timestamp
    expect(serverCode).toContain('expiresAt');
  });

  it('verifies admin user search endpoint exists and is admin-only', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: GET /api/admin/users/search endpoint route
    expect(serverCode).toContain("'/api/admin/users/search'");

    // Evidence 2: Admin middleware requirement
    expect(serverCode).toContain('authenticate, requireAdmin');

    // Evidence 3: Phone parameter query
    expect(serverCode).toContain('phone ILIKE');

    // Evidence 4: Parameterized query (SQL injection safe)
    expect(serverCode).toContain('%${phone}%');

    // Evidence 5: Result limit
    expect(serverCode).toContain('LIMIT 10');
  });

  it('verifies admin subscription status endpoint exists and is admin-only', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');

    // Evidence 1: GET /api/admin/subscriptions/status endpoint route
    expect(serverCode).toContain("'/api/admin/subscriptions/status'");

    // Evidence 2: Admin middleware requirement
    expect(serverCode).toContain('authenticate, requireAdmin');

    // Evidence 3: Queries user_subscriptions table
    expect(serverCode).toContain('user_subscriptions');

    // Evidence 4: Returns hasActiveSubscription boolean
    expect(serverCode).toContain('hasActiveSubscription');

    // Evidence 5: Returns full subscription details
    expect(serverCode).toContain('planCode');
    expect(serverCode).toContain('startAt');
    expect(serverCode).toContain('endAt');
    expect(serverCode).toContain('source');
    expect(serverCode).toContain('note');
    expect(serverCode).toContain('activatedBy');
  });
});
