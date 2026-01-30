# Deploy Checklist (safe to run without secrets)

Commands to prepare and deploy. Do NOT run deploy commands without setting secrets listed in `docs/ENVIRONMENT_VARIABLES.md`.

1. Select Firebase project (use `.firebaserc` or set `FIREBASE_PROJECT` env var):

   - `firebase use --add` or set `FIREBASE_PROJECT` in CI.

2. Build web-admin (if present):

   - `cd web-admin && npm ci && npm run build`

3. Deploy functions (requires `FIREBASE_SERVICE_ACCOUNT` or logged-in user):

   - `cd functions && npm ci && firebase deploy --only functions --project $FIREBASE_PROJECT`

4. Deploy hosting (web):

   - `firebase deploy --only hosting --project $FIREBASE_PROJECT`

5. Deploy Firestore rules and indexes:

   - `firebase deploy --only firestore:rules --project $FIREBASE_PROJECT`
   - `firebase deploy --only firestore:indexes --project $FIREBASE_PROJECT`

6. Storage rules:

   - `firebase deploy --only storage --project $FIREBASE_PROJECT`

What requires secrets:

- Functions requiring Stripe or external API keys will fail if secrets are not set.
- Deploying with a service account is recommended in CI; set `FIREBASE_SERVICE_ACCOUNT` as a secret.

Rollback steps:

- Use `firebase deploy --only hosting --project $FIREBASE_PROJECT --version <previous>` if using channels/versions.
- Revert rules or functions with previous git commit and redeploy.
