# Workflow Summary (deploy.yml)
- backend-test: Node 20; npm ci; lint; npm test with emulators; npm run build for firebase-functions.
- rest-api-test: Node 20; npm ci; lint; npm test (--passWithNoTests) with test env vars; npm run build.
- Deploy gates: deploy-staging waits on backend-test, rest-api-test, mobile-customer-test, mobile-merchant-test.
- Mobile jobs: flutter analyze/test/format for customer and merchant apps.
