# PRODUCT CODE REALITY MAP
## Urban Points Lebanon | source/apps/** and source/backend/** only

**Generated:** 2026-01-23 23:09:50

---

## EXECUTIVE SUMMARY

### Scope
- **Product roots scanned:** source/apps, source/backend
- **Excluded:** node_modules, build, dist, .next, .dart_tool, venv, logs, docs, PDFs, generated artifacts
- **Reads per file:** 100% line-by-line (NO skip)

### File Inventory
- **Total code files:** 363
- **Total bytes:** 2,799,704 (2.8 MB)
- **Total lines of code:** 81,570
- **Average lines/file:** 224

### Code Quality Issues
- **Junk code hits:** 315
- **Dead code candidates:** 169

---

## JUNK CODE PATTERN BREAKDOWN

- **console.log:** 149 occurrences
- **print(:** 146 occurrences
- **PLACEHOLDER:** 11 occurrences
- **debugger:** 6 occurrences
- **TODO:** 3 occurrences

---

## TOP JUNK CODE OCCURRENCES

1. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/analysis_options.yaml:12` [TODO] todo: ignore
2. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:34` [print(] print('⏱️  App startup: ${sw.elapsedMilliseconds}ms');
3. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:37` [print(] print('❌ PAIN: Startup exceeded 10s');
4. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:39` [print(] print('✅ PASS: Startup within limit');
5. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:51` [print(] print('✅ PASS: Merchant flow navigation');
6. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:75` [print(] print('✅ ${entry.key}: ${entry.value}ms');
7. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/integration_test/pain_test.dart:95` [print(] print('⏱️  Network resilience (${delayS}s simulated): ${sw.elapsedMilliseconds}m
8. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/ios/Flutter/ephemeral/flutter_lldb_helper.py:21` [print(] print(f'Failed to write into {base}[+{page_len}]', error)
9. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/ios/Flutter/ephemeral/flutter_lldb_helper.py:24` [debugger] def __lldb_init_module(debugger: lldb.SBDebugger, _):
10. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/ios/Flutter/ephemeral/flutter_lldb_helper.py:25` [debugger] target = debugger.GetDummyTarget()
11. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/ios/Flutter/ephemeral/flutter_lldb_helper.py:32` [print(] print("-- LLDB integration loaded --")
12. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/lib/screens/notifications_screen.dart:381` [TODO] // TODO: Navigate to relevant screen based on type
13. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/lib/widgets/reconciled/reconciled_offline_banner.dart:10` [TODO] /// TODO: To activate this widget:
14. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:12` [print(] print('========================================');
15. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:13` [print(] print('🧪 DAY 2 AUTH SANITY CHECK - CUSTOMER APP');
16. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:14` [print(] print('========================================\n');
17. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:17` [print(] print('📱 Step 1: Initializing Firebase...');
18. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:22` [print(] print('✅ Firebase initialized successfully');
19. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:23` [print(] print('   Project: ${DefaultFirebaseOptions.currentPlatform.projectId}');
20. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:25` [print(] print('❌ FAIL: Firebase initialization failed: $e');
21. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:30` [print(] print('\n📱 Step 2: Checking current user...');
22. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:35` [print(] print('ℹ️  No user currently signed in');
23. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:37` [print(] print('✅ User signed in:');
24. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:38` [print(] print('   UID: ${currentUser.uid}');
25. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:39` [print(] print('   Email: ${currentUser.email}');
26. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:40` [print(] print('   Email Verified: ${currentUser.emailVerified}');
27. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:48` [print(] print('\n📱 Step 3: Testing sign-in with provided credentials...');
28. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:53` [print(] print('   Signed out previous user');
29. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:62` [print(] print('✅ Sign-in successful');
30. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:63` [print(] print('   UID: ${user.uid}');
31. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:64` [print(] print('   Email: ${user.email}');
32. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:67` [print(] print('\n📱 Step 4: Fetching ID token and custom claims...');
33. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:72` [print(] print('✅ ID token retrieved');
34. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:73` [print(] print('   Token expires: ${idTokenResult.expirationTime}');
35. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:74` [print(] print('   Custom claims role: ${role ?? "NOT SET"}');
36. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:77` [print(] print('\n📱 Step 5: Checking Firestore user document...');
37. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:84` [print(] print('❌ FAIL: User document does not exist in Firestore /users/${user.uid}');
38. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:85` [print(] print('   Expected: Document created by onUserCreate trigger');
39. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:93` [print(] print('✅ User document found');
40. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:94` [print(] print('   Firestore role: ${firestoreRole ?? "NOT SET"}');
41. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:95` [print(] print('   isActive: $isActive');
42. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:96` [print(] print('   email: ${userData['email']}');
43. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:97` [print(] print('   pointsBalance: ${userData['pointsBalance']}');
44. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:100` [print(] print('\n📱 Step 6: Validating role for Customer app...');
45. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:105` [print(] print('❌ FAIL: No role found in custom claims or Firestore');
46. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:110` [print(] print('❌ FAIL: Invalid role for Customer app');
47. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:111` [print(] print('   Expected: customer or user');
48. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:112` [print(] print('   Got: $effectiveRole');
49. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:117` [print(] print('❌ FAIL: User is not active (isActive: false)');
50. `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-customer/tool/auth_sanity.dart:121` [print(] print('✅ Role validation PASSED');

... and 265 more in JUNK_CODE.json

---

## DEAD CODE CANDIDATES

**Total:** 169 unreferenced files

Sample:
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/pubspec.yaml` (4,287 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/analysis_options.yaml` (402 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/integration_test/pain_test.dart` (1,306 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/macos/RunnerTests/RunnerTests.swift` (290 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/macos/Runner/MainFlutterWindow.swift` (388 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/macos/Runner/AppDelegate.swift` (311 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/macos/Flutter/GeneratedPluginRegistrant.swift` (1,265 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/macos/Flutter/ephemeral/flutter_export_environment.sh` (518 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/test/redemption_approval_test.dart` (116 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/test/widget_test.dart` (2,234 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/test/offer_creation_test.dart` (116 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/web/firebase-messaging-sw.js` (2,235 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/web/manifest.json` (995 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/RunnerTests/RunnerTests.swift` (285 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Runner/Runner-Bridging-Header.h` (38 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Runner/AppDelegate.swift` (391 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Runner/GeneratedPluginRegistrant.m` (2,637 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` (391 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Flutter/flutter_export_environment.sh` (556 bytes)
- `/Users/mohammadzeineddine/Downloads/URBAN_POINTS_LEBANON_CTO_FORENSIC_HANDOVER/source/apps/mobile-merchant/ios/Flutter/ephemeral/flutter_lldb_helper.py` (1,276 bytes)

... and 149 more in DEAD_CODE.json

---

## READ ERRORS & COMPLETENESS

**Read errors encountered:** 0

---

## RECOMMENDATIONS

1. **Clean junk code:** Remove 295 debug statements
2. **Review TODOs:** Address 3 TODO comments
3. **Evaluate dead code:** Review 169 potentially unreferenced files
4. **Remove placeholder code:** Clean 11 placeholder entries

---

**Analysis Details:** See FILES_READ.json, JUNK_CODE.json, DEAD_CODE.json
