# Disabled Integration Tests

These tests are disabled for CI because they require Firebase emulators and proper firestore.rules paths.

To re-enable:
1. Start Firebase emulators
2. Fix filesystem paths to firestore.rules relative to the test runtime
3. Remove the .skip.ts suffix and update tsconfig/jest ignore patterns as needed
