# Performance & Scale Plan (Evidence-Only)

Focus areas grounded in current stack:
- Firebase Cloud Functions (Node): latency, cold starts, concurrency
- Firestore: read/write throughput, index utilization, hot partitions
- REST API (Express) + PostgreSQL: p95/p99 latency, connection pooling, query plans
- Mobile: startup time, offline behavior, crash rates
- Web Admin: E2E stability under load (Playwright scenarios)

## Metrics to Collect
- REST API: p95 latency per endpoint, error rate, throughput (req/s)
- Firestore: reads/writes per second, contention, index scans
- Functions: cold start rate, avg duration, memory footprints
- Mobile: app start time, frame drops, ANR/crash metrics
- Web Admin: page TTI, E2E run stability (retry rates)

## Tools
- Firebase Emulator + `firebase-tools` metrics
- Node profiling (clinic.js, pprof), pg `EXPLAIN ANALYZE`
- Playwright trace viewer
- Flutter `integration_test` perf logs

## Evidence Targets
- local-ci/verification/perf/REST_API_metrics.json
- local-ci/verification/perf/Firestore_metrics.json
- local-ci/verification/perf/Functions_metrics.json
- local-ci/verification/perf/Mobile_metrics.json
- local-ci/verification/perf/WebAdmin_metrics.json

## Current Status
- Evidence missing (no perf artifacts). Block on env setup and real runs.

## Acceptance
- Produce all metric artifacts above, with manifest.json and sha256 hashes per run.
