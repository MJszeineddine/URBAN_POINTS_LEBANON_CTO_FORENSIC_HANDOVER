# BLOCKER: UP-FS-009 Legacy REST API (Express/Postgres)

## Requirement ID
UP-FS-009 (legacy_rest_api)

## Status
BLOCKED

## Description
Express server in `source/backend/rest-api/` provides JWT-authenticated REST endpoints for auth, offers, vouchers, and gifts. Server code is implemented and uses Postgres via node-postgres (`pg`) pool, but database schema (tables, indexes, stored functions) is **not present in the repository**.

## Blocker Details

### Missing Database Schema
- **Tables**: `users`, `offers`, `transactions`, `vouchers`, `voucher_redemptions`, `gifts` (inferred from code queries)
- **Stored Functions**: 
  - `healthcheck()`: Called by `/api/health` endpoint
  - `validate_redemption(...)`: Called by `/api/vouchers/:id/redeem` to enforce one-time redemption and point deduction
- **Indexes and Constraints**: Unknown; must be defined to support concurrent writes and performance

### Missing Environment Variables
- `DATABASE_URL`: Postgres connection string (format: `postgres://user:pass@host:port/dbname`)
- `JWT_SECRET`: Secret for signing and verifying JWT tokens

### Code References
- [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts): Express app mounts routes; calls `pool.query()` for database access
- [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts#L20): Health route executes `SELECT healthcheck()` 
- [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts#L95): Register endpoint inserts into `users` table with hashed password
- [source/backend/rest-api/src/server.ts](source/backend/rest-api/src/server.ts#L245): Voucher redemption calls `SELECT validate_redemption($1, $2)`

### Acceptance Criteria (Blocked)
- ❌ Postgres schema migration scripts created with tables for users, offers, transactions, vouchers, voucher_redemptions, gifts
- ❌ Stored functions `healthcheck()` and `validate_redemption(voucher_id, user_id)` defined in SQL
- ❌ `DATABASE_URL` configured pointing to accessible Postgres instance
- ❌ `JWT_SECRET` set for token signing
- ❌ Server starts successfully with `/api/health` returning 200 OK
- ❌ Register/login flow produces valid JWT tokens; protected routes enforce token validation
- ❌ Voucher purchase/redeem transactions execute without schema errors

## Unblock Actions Required

1. **Create Schema Migration Scripts**
   - Define SQL DDL for all tables used in [server.ts](source/backend/rest-api/src/server.ts)
   - Example: 
     ```sql
     CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       email VARCHAR(255) UNIQUE NOT NULL,
       password_hash TEXT NOT NULL,
       role VARCHAR(50) DEFAULT 'customer',
       is_active BOOLEAN DEFAULT true,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );
     
     CREATE TABLE vouchers (
       id SERIAL PRIMARY KEY,
       user_id INTEGER REFERENCES users(id),
       offer_id INTEGER REFERENCES offers(id),
       status VARCHAR(50) DEFAULT 'active',
       created_at TIMESTAMPTZ DEFAULT NOW()
     );
     
     CREATE OR REPLACE FUNCTION healthcheck() RETURNS TEXT AS $$
     BEGIN
       RETURN 'ok';
     END;
     $$ LANGUAGE plpgsql;
     
     CREATE OR REPLACE FUNCTION validate_redemption(v_id INTEGER, u_id INTEGER) 
     RETURNS BOOLEAN AS $$
     DECLARE
       redemption_exists BOOLEAN;
     BEGIN
       SELECT EXISTS(SELECT 1 FROM voucher_redemptions WHERE voucher_id = v_id AND user_id = u_id)
       INTO redemption_exists;
       RETURN NOT redemption_exists;
     END;
     $$ LANGUAGE plpgsql;
     ```
   - Store migration scripts in `source/backend/rest-api/migrations/` or similar

2. **Provision Postgres Database**
   - Deploy Postgres instance (local Docker, managed cloud service, or Firebase Cloud SQL)
   - Run migration scripts to initialize schema
   - Example Docker local setup:
     ```bash
     docker run --name urban-points-postgres -e POSTGRES_PASSWORD=secret -p 5432:5432 -d postgres:15
     psql -h localhost -U postgres -d postgres -f migrations/001_init_schema.sql
     ```

3. **Configure Environment**
   - Set `DATABASE_URL` in `.env` or runtime environment:
     ```bash
     export DATABASE_URL="postgres://postgres:secret@localhost:5432/urban_points"
     export JWT_SECRET="your-strong-random-secret"
     ```

4. **Test Server Startup**
   ```bash
   cd source/backend/rest-api
   npm install
   npm start
   # Verify health endpoint: curl http://localhost:3000/api/health
   ```

5. **End-to-End Validation**
   - Register new user via `/api/auth/register`
   - Login to obtain JWT
   - Call protected routes (e.g., `/api/offers`) with Authorization header
   - Test voucher purchase and redemption flows

## Impact
- Legacy REST API server cannot start without schema (health check fails)
- All voucher/gift endpoints fail with SQL errors
- UP-FS-009 cannot transition to READY without database schema deployed and tested

## Notes
- REST API is considered "legacy" but may still serve clients not yet migrated to Firebase
- Schema should match data model implied by Firebase Firestore collections (users, offers, etc.) for consistency
- Consider adding database connection pooling configuration and retry logic for production
- If legacy API is no longer needed, consider deprecating/removing and marking UP-FS-009 as OBSOLETE

## References
- [UP-FS-009 spec](spec/requirements.yaml#L144-L172)
- [REST API server code](source/backend/rest-api/src/server.ts)
- [REST API package.json](source/backend/rest-api/package.json)
