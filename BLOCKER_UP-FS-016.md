# BLOCKER: UP-FS-016 Observability & Release Automation

## Requirement ID
UP-FS-016 (observability_release)

## Status
BLOCKED

## Description
Production readiness for Firebase Functions, schedulers, and web assets requires structured logging, monitoring dashboards, alerting, error budgets, and CI/CD pipeline automation. Code lacks observability instrumentation and no CI/CD pipeline definitions exist in the repository.

## Blocker Details

### Missing Observability Infrastructure
- **Structured Logging**: Functions currently use `console.log` without correlation IDs, trace context, or consistent log levels
- **Metrics & Dashboards**: No Prometheus/Grafana, Google Cloud Monitoring dashboards, or equivalent configured
- **Alerting Rules**: No PagerDuty/Slack/email alerts for scheduler failures, high error rates, or latency spikes
- **Error Budgets**: No SLO definitions or burn-rate alerts for critical flows (auth, QR redemption, points earning)

### Missing CI/CD Pipeline
- **Pipeline Configuration**: No GitHub Actions, CircleCI, Cloud Build, or similar YAML definitions in repo
- **Deployment Automation**: Manual `firebase deploy` required; no automated promotion from staging to production
- **Approval Gates**: No human approval steps before production deployment of rules or functions
- **Rollback Procedures**: No automated rollback scripts or runbooks for incident response

### Code References
- [source/backend/firebase-functions/src/index.ts](source/backend/firebase-functions/src/index.ts): Functions exports lack structured logging middleware
- [tools/final_release_gate.sh](tools/final_release_gate.sh): Gate script exists but not wired to CI/CD automation

### Acceptance Criteria (Blocked)
- ❌ Structured logging library integrated (e.g., Winston, Pino, or Google Cloud Logging SDK) with correlation IDs and trace propagation
- ❌ Google Cloud Monitoring dashboards created for:
  - Function invocation counts, latencies, error rates (broken down by callable name)
  - Scheduler job success/failure counts (`enforceMerchantCompliance`, `cleanupExpiredQRTokens`, `sendPointsExpiryWarnings`)
  - QR token generation/redemption success rates
  - Points earning/redemption transaction volumes
- ❌ Alerting policies configured:
  - Scheduler job failures > 2 in 10 minutes
  - Callable error rate > 5% for 5 minutes
  - QR redemption failure rate > 10% for 10 minutes
- ❌ CI/CD pipeline YAML (e.g., `.github/workflows/deploy.yml`) defining:
  - Build/lint/test steps for functions, web-admin, Flutter apps
  - Staging deployment on PR merge to `main`
  - Production deployment on tag/release with manual approval
  - Firestore rules/indexes deployment as separate stage
- ❌ Runbook documentation in `docs/RUNBOOK_INCIDENT_RESPONSE.md` with rollback procedures and escalation contacts

## Unblock Actions Required

### 1. Add Structured Logging
Integrate logging library and add correlation IDs to all callables:

```typescript
import { logger } from 'firebase-functions/v2';

export const earnPoints = onCall((request) => {
  const correlationId = request.data.correlationId || generateUUID();
  logger.info('earnPoints invoked', { correlationId, uid: request.auth?.uid });
  // ... existing logic
  logger.info('earnPoints completed', { correlationId, pointsEarned: result.points });
});
```

Create middleware for automatic trace context injection.

### 2. Create Monitoring Dashboards
Example Google Cloud Monitoring dashboard JSON:

```json
{
  "displayName": "Urban Points Production",
  "dashboardFilters": [],
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Function Invocations",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_function\" metric.type=\"cloudfunctions.googleapis.com/function/execution_count\"",
                  "aggregation": { "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE" }
                }
              }
            }]
          }
        }
      }
    ]
  }
}
```

Deploy via `gcloud monitoring dashboards create --config-from-file=dashboard.json`.

### 3. Configure Alerting Policies
Example alert for scheduler failures:

```yaml
displayName: "Scheduler Job Failures"
conditions:
  - displayName: "Scheduler failure rate"
    conditionThreshold:
      filter: 'resource.type="cloud_function" AND metric.type="cloudfunctions.googleapis.com/function/execution_count" AND metric.label.status="error" AND resource.label.function_name=~"enforceMerchantCompliance|cleanupExpiredQRTokens"'
      comparison: COMPARISON_GT
      thresholdValue: 2
      duration: "600s"
notificationChannels:
  - projects/PROJECT_ID/notificationChannels/CHANNEL_ID
```

Deploy via `gcloud alpha monitoring policies create --policy-from-file=alert.yaml`.

### 4. Build CI/CD Pipeline
Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Firebase

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: cd source/backend/firebase-functions && npm ci && npm test

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: cd source && firebase deploy --only functions,firestore:rules --project staging-project

  deploy-production:
    needs: test
    if: github.event_name == 'release'
    environment:
      name: production
      url: https://urbanpoints.app
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: cd source && firebase deploy --only functions,firestore:rules --project prod-project
```

Add GitHub environment protection rules requiring manual approval for production.

### 5. Document Runbook
Expand [docs/RUNBOOK_INCIDENT_RESPONSE.md](docs/RUNBOOK_INCIDENT_RESPONSE.md):

- Rollback procedure: `firebase deploy --only functions:functionName --version PREVIOUS_VERSION`
- Escalation contacts: CTO, on-call engineer
- Common incidents: scheduler stuck, Firestore quota exceeded, webhook signature failures
- Debugging steps: check Cloud Logging, verify environment variables, inspect Firestore rules

### 6. Define SLOs and Error Budgets
Example SLO definitions:

| Flow | SLI | Target | Error Budget |
|------|-----|--------|--------------|
| QR Redemption | Success rate | 99% | 1% failures over 30 days |
| Points Earning | Latency p95 | < 500ms | 5% above threshold |
| Scheduler Jobs | Completion rate | 99.9% | 0.1% failures over 7 days |

Implement burn-rate alerts to notify when budget consumption accelerates.

## Impact
- No production visibility into system health or failure modes
- Manual deployments increase risk of human error and downtime
- Incident response delayed by lack of runbooks and rollback automation
- UP-FS-016 cannot transition to READY without observability and CI/CD infrastructure

## Decision Points
- **Monitoring Platform**: Google Cloud Monitoring (recommended for Firebase), Datadog, Grafana Cloud?
- **CI/CD Platform**: GitHub Actions (recommended for GitHub repos), Cloud Build, CircleCI?
- **Alerting Destinations**: PagerDuty, Slack webhook, email distribution list?
- **Log Aggregation**: Cloud Logging (default), Elasticsearch/Kibana, Splunk?

## Notes
- Observability should be additive and not break existing functionality
- Start with high-level dashboards (function invocations, error rates) before detailed traces
- CI/CD pipeline can begin with staging-only automation before requiring production approvals
- Runbook documentation can start minimal and expand as incidents are encountered

## References
- [UP-FS-016 spec](spec/requirements.yaml#L285-L310)
- [Firebase Functions logging best practices](https://firebase.google.com/docs/functions/writing-and-viewing-logs)
- [Google Cloud Monitoring quickstart](https://cloud.google.com/monitoring/docs/monitoring-overview)
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Existing runbook stub](docs/RUNBOOK_INCIDENT_RESPONSE.md)
