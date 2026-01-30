# REQUIRED Environment Variables - Evidence-Based Analysis

**Date:** Generated during staging gate restoration  
**Purpose:** Evidence-based detection of REQUIRED vs OPTIONAL environment variables  
**Gate Scope:** Firebase Functions + REST API (web-admin is client-side, no server-side secrets)

---

## Classification Rules

- **Rule (a) - Module-Level / Unconditional:** Env var checked at module initialization (before any request handling). Missing var → Module fails to load → Immediate startup failure.
- **Rule (b) - Feature-Flagged (Default-Enabled):** Var behind a feature flag that is enabled by default in production → Must be provided.
- **Rule (c) - Feature-Flagged (Default-Disabled):** Var behind a feature flag disabled by default or opt-in → Optional at gate level.
- **Rule (d) - Test-Only:** Only used in `__tests__/` directories → Skip (not deployment-relevant).
- **Rule (e) - Runtime-Optional:** Checked at function invocation level with graceful fallback → Optional.

---

## Firebase Functions (source/backend/firebase-functions/src/)

### 1. QR_TOKEN_SECRET ✅ REQUIRED

**Rule:** (a) Module-Level / Unconditional  
**Evidence:** [source/backend/firebase-functions/src/index.ts#L58-L60](source/backend/firebase-functions/src/index.ts#L58-L60)

```typescript
if (!process.env.FUNCTIONS_EMULATOR && !process.env.QR_TOKEN_SECRET && !functions.config().secrets?.qr_token_secret) {
  throw new Error('QR_TOKEN_SECRET is required for production QR code generation');
}
```

**Analysis:**
- Checked at module initialization (line 58-60, before any request handling)
- Throws error if missing in production (`!process.env.FUNCTIONS_EMULATOR`)
- Used at [line 216](source/backend/firebase-functions/src/index.ts#L216), [line 276](source/backend/firebase-functions/src/index.ts#L276) in request handlers
- **Status:** Module cannot load without it in production
- **Sensitivity:** HIGH (cryptographic secret for QR code generation)

---

### 2. STRIPE_SECRET_KEY ⚠️ RUNTIME-OPTIONAL (NOT REQUIRED)

**Rule:** (e) Runtime-Optional  
**Evidence:** [source/backend/firebase-functions/src/stripe.ts#L31](source/backend/firebase-functions/src/stripe.ts#L31), [line 37](source/backend/firebase-functions/src/stripe.ts#L37)

```typescript
const enabled = process.env.STRIPE_ENABLED || functions.config().stripe?.enabled || '1';
return process.env.STRIPE_SECRET_KEY || functions.config().stripe?.secret_key || null;
```

**Analysis:**
- Not checked at module initialization (no top-level throw)
- Used only in Stripe-specific functions (`handleStripeWebhook`, `createStripeCustomer`, etc.)
- Gracefully returns `null` if missing (line 37)
- Flag-gated: if `STRIPE_ENABLED='0'`, Stripe functions are disabled
- **Status:** Can start without it; will fail only on Stripe-specific requests
- **Sensitivity:** HIGH (payment processing key)
- **Gate Decision:** NOT_REQUIRED at deployment gate (will be caught at runtime if Stripe features used without key)

---

### 3. FUNCTIONS_EMULATOR 📝 RUNTIME-DECISION (NOT REQUIRED)

**Rule:** (e) Runtime-Optional / Environment-Conditional  
**Evidence:** [source/backend/firebase-functions/src/index.ts#L54](source/backend/firebase-functions/src/index.ts#L54)

```typescript
environment: process.env.FUNCTIONS_EMULATOR === 'true' ? 'development' : 'production'
```

**Analysis:**
- Determines if running in emulator (development) or production
- Not throwing if missing; defaults to production behavior
- Used for conditional security checks (e.g., `!process.env.FUNCTIONS_EMULATOR` in line 58)
- **Status:** Optional; defaults to production mode
- **Gate Decision:** NOT_REQUIRED (sensible default provided)

---

### Other Env Vars in Firebase Functions

- **SENTRY_DSN**: [source/backend/firebase-functions/src/monitoring.ts#L12](source/backend/firebase-functions/src/monitoring.ts#L12) → Optional monitoring (not checked at module-level, returns undefined)
- **TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER**: [source/backend/firebase-functions/src/whatsapp.ts#L85-L87](source/backend/firebase-functions/src/whatsapp.ts#L85-L87) → Runtime-optional (used only if SMS feature called)
- **GCLOUD_PROJECT, LOG_LEVEL**: [source/backend/firebase-functions/src/logger.ts#L21](source/backend/firebase-functions/src/logger.ts#L21) → Auto-provided by Firebase runtime; optional override

---

## REST API (source/backend/rest-api/src/)

### 1. JWT_SECRET ✅ REQUIRED

**Rule:** (a) Module-Level / Unconditional  
**Evidence:** [source/backend/rest-api/src/server.ts#L21](source/backend/rest-api/src/server.ts#L21), [line 22](source/backend/rest-api/src/server.ts#L22)

```typescript
function ensureRequiredEnv() {
  const missing: string[] = [];
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length === 0) {
    missing.push('JWT_SECRET');
  }
  // ... more checks ...
  if (missing.length > 0) {
    console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }
}

ensureRequiredEnv();  // Called at module init (line 34)
```

**Analysis:**
- Checked in `ensureRequiredEnv()` called at module initialization (line 34)
- Explicit validation: cannot be empty string
- Used in JWT middleware ([line 70](source/backend/rest-api/src/server.ts#L70), [line 152](source/backend/rest-api/src/server.ts#L152), [line 153](source/backend/rest-api/src/server.ts#L153), [line 202](source/backend/rest-api/src/server.ts#L202), [line 203](source/backend/rest-api/src/server.ts#L203))
- **Status:** Startup fails if missing (non-zero exit)
- **Sensitivity:** HIGH (authentication token secret)

---

### 2. DATABASE_URL ✅ REQUIRED

**Rule:** (a) Module-Level / Unconditional  
**Evidence:** [source/backend/rest-api/src/server.ts#L24](source/backend/rest-api/src/server.ts#L24), [line 25](source/backend/rest-api/src/server.ts#L25), [line 39](source/backend/rest-api/src/server.ts#L39)

```typescript
if (!process.env.DATABASE_URL || process.env.DATABASE_URL.trim().length === 0) {
  missing.push('DATABASE_URL');
}
// ... process.exit(1) if missing ...

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // ...
});
```

**Analysis:**
- Checked at module init (`ensureRequiredEnv()`, called line 34)
- Explicit validation: cannot be empty string
- Used immediately to create database connection pool
- Without DB connection, all business logic fails
- **Status:** Startup fails if missing (non-zero exit)
- **Sensitivity:** HIGH (database credentials and connection string)

---

### Other Env Vars in REST API

- **CORS_ORIGIN**: [source/backend/rest-api/src/server.ts#L50](source/backend/rest-api/src/server.ts#L50) → Optional, defaults to `'*'`
- **API_RATE_LIMIT_WINDOW_MS, API_RATE_LIMIT_MAX_REQUESTS**: [source/backend/rest-api/src/server.ts#L58-L59](source/backend/rest-api/src/server.ts#L58-L59) → Optional, have sensible defaults
- **PORT**: [source/backend/rest-api/src/server.ts#L16](source/backend/rest-api/src/server.ts#L16) → Optional, defaults to `3000`
- **NODE_ENV, TIMEZONE, COUNTRY_CODE, PAYMENTS_ENABLED**: [source/backend/rest-api/src/server.ts#L805-L809](source/backend/rest-api/src/server.ts#L805-L809) → Logged but not validated; optional

---

## Web Admin (source/apps/web-admin/)

**Status:** Client-side Next.js app (no server-side execution in staging gate)

**Note:** Web-admin runs as a client-side app. Server-side env vars are not relevant for deployment gate testing. NEXT_PUBLIC_* vars are available to both client and server but are not cryptographic secrets requiring gate validation.

---

## Summary: REQUIRED Environment Variables for Staging Gate

| Variable | Component | Rule | File:Line | Validation | Status |
|----------|-----------|------|-----------|------------|--------|
| **QR_TOKEN_SECRET** | Firebase Functions | (a) Module-init | [index.ts#L58-L60](source/backend/firebase-functions/src/index.ts#L58-L60) | Throws if missing | ✅ REQUIRED |
| **JWT_SECRET** | REST API | (a) Module-init | [server.ts#L21-L22](source/backend/rest-api/src/server.ts#L21-L22) | Validated non-empty, exit(1) | ✅ REQUIRED |
| **DATABASE_URL** | REST API | (a) Module-init | [server.ts#L24-L25](source/backend/rest-api/src/server.ts#L24-L25) | Validated non-empty, exit(1) | ✅ REQUIRED |

---

## OPTIONAL Environment Variables (Not Gate-Blocking)

- `STRIPE_SECRET_KEY` (runtime-optional, graceful fallback)
- `STRIPE_WEBHOOK_SECRET` (required only when Stripe webhooks enabled)
- `ALLOW_STRIPE_TEST_KEYS` (set to `1` only in emulator/CI to permit `sk_test_*` keys)
- `FUNCTIONS_EMULATOR` (runtime-decision, sensible default)
- `SENTRY_DSN` (monitoring, optional)
- `TWILIO_*` (feature-specific, runtime-optional)
- `CORS_ORIGIN` (has default)
- `API_RATE_LIMIT_*` (has defaults)
- `PORT` (has default)
- `NEXT_PUBLIC_*` (client-side, not secrets)

---

## Gate Implementation Requirements

The staging gate must:

1. **Load .env.local** before scanning (to get current env state)
2. **Check REQUIRED vars** in strict mode (fail gate if any missing)
3. **Skip OPTIONAL vars** (no gate failure, but log for visibility)
4. **Create BLOCKER.md** if any REQUIRED var is missing (with file:line evidence)
5. **Redact sensitive values** in logs (don't print secret keys)
6. **Set FINAL_GATE.txt = FAIL** if missing REQUIRED vars (strict STOP behavior)

---

## References

- Firebase Functions Index: [source/backend/firebase-functions/src/index.ts](source/backend/firebase-functions/src/index.ts)
- REST API Server: [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts)
- Stripe Integration: [source/backend/firebase-functions/src/stripe.ts](source/backend/firebase-functions/src/stripe.ts)
- Monitoring: [source/backend/firebase-functions/src/monitoring.ts](source/backend/firebase-functions/src/monitoring.ts)

