# BLOCKER: Mobile Merchant Build/Test

**Status:** BLOCKED

**Reason:** Flutter SDK not available in environment

**Evidence:**
- Command: `which flutter`
- Exit code: Non-zero (Flutter not found)
- Path checked: source/apps/mobile-merchant/

**Impact:**
- Cannot run flutter pub get
- Cannot run flutter analyze
- Cannot run flutter test
- Cannot run flutter build

**How to Unblock:**
1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Add Flutter to PATH
3. Run: flutter doctor -v
4. Verify: flutter --version
5. Re-run audit build/test phase

**Evidence Path:** local-ci/verification/micro_audit/LATEST/build_test/mobile_merchant_flutter_check.log
