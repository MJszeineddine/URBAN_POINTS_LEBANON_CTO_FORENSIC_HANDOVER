# BLOCKER — BACKEND-DATA-001

**Requirement:** Remove Mock Data from Analytics  
**Status:** BLOCKED  
**Category:** Data Quality, Backend Refactoring  

---

## Why BLOCKED

The `calculateDailyStats` function contains placeholder/mock data instead of real Firestore aggregation queries. Full remediation requires:

1. **Audit all mock data sources** in backend codebase
2. **Implement real Firestore queries** for:
   - Daily redemption counts by offer/merchant
   - Daily signup counts by channel
   - Active offers count
   - Points issued/redeemed totals
3. **Optimize queries** for performance (indexing, pagination)
4. **Add tests** for aggregation accuracy
5. **Remove/deprecate** mock data generation

This is a **backend audit + implementation** task requiring database schema understanding and performance optimization.

## Evidence Required

- ✅ All mock data removed from analytics functions
- ✅ Real Firestore queries implemented with performance testing
- ✅ Dashboard displays accurate real data
- ✅ Query performance acceptable (<2s per dashboard load)
- ✅ Unit and integration tests for aggregation logic

## Next Steps

1. Audit all functions for mock data usage
2. Replace with real Firestore queries
3. Implement caching if needed for performance
4. Test accuracy with production-like data volumes

---

**Document Created:** 2026-01-16
