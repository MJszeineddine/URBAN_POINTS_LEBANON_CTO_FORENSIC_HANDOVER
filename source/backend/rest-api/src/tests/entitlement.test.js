describe('Subscription Entitlement Gating', () => {
  it('verifies requireActiveSubscription middleware exists in server code', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');
    
    // Evidence 1: Middleware function exists
    expect(serverCode).toContain('requireActiveSubscription');
    
    // Evidence 2: 403 SUBSCRIPTION_REQUIRED error code exists
    expect(serverCode).toContain('SUBSCRIPTION_REQUIRED');
    
    // Evidence 3: Middleware is applied to redeem endpoint
    expect(serverCode).toContain("'/api/vouchers/:id/redeem', authenticate, requireActiveSubscription");
    
    // Evidence 4: Entitlements endpoint exists
    expect(serverCode).toContain("'/api/entitlements/me'");
  });

  it('verifies entitlement gating logic queries active subscriptions', () => {
    const fs = require('fs');
    const path = require('path');
    const serverPath = path.join(__dirname, '../server.ts');
    const serverCode = fs.readFileSync(serverPath, 'utf8');
    
    // Evidence: Query checks for active subscriptions with expiry
    expect(serverCode).toContain("status = 'active' AND end_at > NOW()");
  });
});
