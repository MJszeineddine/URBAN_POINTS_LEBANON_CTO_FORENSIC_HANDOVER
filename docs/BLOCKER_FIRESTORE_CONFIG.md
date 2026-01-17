# Blocker: Firestore Configuration Files

**Requirement IDs:** INFRA-RULES-001, INFRA-INDEX-001

## Issue
The following Firestore configuration files are not present in the repository:
- `source/firestore.rules` (Firestore security rules)
- `source/firestore.indexes.json` (Firestore composite indexes)

## Why It Blocks
These files are required for:
1. **INFRA-RULES-001:** Firestore security rules enforcement in production
2. **INFRA-INDEX-001:** Composite index configuration for complex queries

## Blocker Details

### firestore.rules
- Must define access control for all collections (users, merchants, offers, points, redemptions, etc.)
- Must enforce role-based access (customer vs merchant vs admin)
- Currently not in repo - suggests rules deployed via Firebase CLI or inline

**Failing Command:** Cannot validate Firestore rules without file

### firestore.indexes.json
- Must define composite indexes for queries on (userId, status), (merchantId, createdAt), etc.
- Currently not in repo - suggests indexes deployed via Firebase Console or auto-generated

**Failing Command:** Cannot deploy indexes without file

## Resolution
Choose one:

### Option 1: Extract from Firebase Console (Recommended)
```bash
firebase firestore:indexes --json > source/firestore.indexes.json
firebase firestore:rules:get > source/firestore.rules
git add source/firestore.* && git commit -m "feat: Add Firestore configuration"
```

### Option 2: Create from scratch
Create minimal rules and indexes that enforce:
- Users can only read/write their own document
- Merchants can only read/write offers they created
- Admins have full access
- All writes go through backend validation

### Status
**Marked BLOCKED** because external Firebase console access is required.

**Unblock When:**
- `source/firestore.rules` exists and is non-empty
- `source/firestore.indexes.json` exists and is non-empty
