// k6 Load Test for Urban Points Lebanon - Direct Firestore Operations
// PHASE 3: LOAD/STRESS TESTING (Firestore Emulator)
// Timestamp: 2025-12-29
// Target: Firestore Emulator via REST API

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const firestoreLatency = new Trend('firestore_latency');

// Test configuration profiles
export const options = {
  stages: [
    // Profile 1: Warmup
    { duration: '30s', target: 10 },   // Ramp up to 10 users
    // Profile 2: Normal Load  
    { duration: '1m', target: 30 },    // Ramp to 30 users
    { duration: '2m', target: 30 },    // Hold at 30 users
    // Profile 3: Stress Test
    { duration: '30s', target: 60 },   // Spike to 60 users
    { duration: '1m', target: 60 },    // Hold at 60 users
    // Profile 4: Cool Down
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    // Performance thresholds for Firestore
    http_req_duration: ['p(95)<1000'], // 95% under 1s
    http_req_failed: ['rate<0.10'],    // Error rate under 10%
    errors: ['rate<0.10'],
  },
};

// Firestore REST API endpoint
const FIRESTORE_BASE = 'http://localhost:8080/v1/projects/urbangenspark-test/databases/(default)/documents';

// Test identifiers
const VU_PREFIX = `loadtest_vu`;

// Scenario 1: Read Offers Collection
function readOffers() {
  const start = Date.now();
  const res = http.get(`${FIRESTORE_BASE}/offers?pageSize=50`);
  const latency = Date.now() - start;
  
  const success = check(res, {
    'read offers: status 200': (r) => r.status === 200,
    'read offers: has documents': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.documents !== undefined;
      } catch (e) {
        return false;
      }
    },
  });
  
  firestoreLatency.add(latency);
  errorRate.add(!success);
  sleep(0.5);
}

// Scenario 2: Read Customer Document
function readCustomer() {
  const customerId = `${VU_PREFIX}${__VU}`;
  const start = Date.now();
  const res = http.get(`${FIRESTORE_BASE}/customers/${customerId}`);
  const latency = Date.now() - start;
  
  const success = check(res, {
    'read customer: status in [200,404]': (r) => r.status === 200 || r.status === 404,
  });
  
  firestoreLatency.add(latency);
  errorRate.add(!success);
  sleep(0.5);
}

// Scenario 3: Write Customer Document
function writeCustomer() {
  const customerId = `${VU_PREFIX}${__VU}_${__ITER}`;
  const start = Date.now();
  
  const payload = JSON.stringify({
    fields: {
      name: { stringValue: `Load Test User ${__VU}` },
      email: { stringValue: `loadtest${__VU}@test.com` },
      points_balance: { integerValue: '1000' },
      subscription_status: { stringValue: 'active' },
      subscription_plan: { stringValue: 'premium' },
      created_at: { timestampValue: new Date().toISOString() },
    },
  });
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  const res = http.patch(
    `${FIRESTORE_BASE}/customers/${customerId}?updateMask.fieldPaths=name&updateMask.fieldPaths=email&updateMask.fieldPaths=points_balance&updateMask.fieldPaths=subscription_status&updateMask.fieldPaths=subscription_plan&updateMask.fieldPaths=created_at`,
    payload,
    params
  );
  const latency = Date.now() - start;
  
  const success = check(res, {
    'write customer: status 200': (r) => r.status === 200,
  });
  
  firestoreLatency.add(latency);
  errorRate.add(!success);
  sleep(1);
}

// Scenario 4: Query Redemptions
function queryRedemptions() {
  const customerId = `${VU_PREFIX}${__VU}`;
  const start = Date.now();
  
  // Structured query for redemptions
  const query = {
    structuredQuery: {
      from: [{ collectionId: 'redemptions' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'customer_id' },
          op: 'EQUAL',
          value: { stringValue: customerId },
        },
      },
      limit: 10,
    },
  };
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  const res = http.post(
    `${FIRESTORE_BASE}:runQuery`,
    JSON.stringify(query),
    params
  );
  const latency = Date.now() - start;
  
  const success = check(res, {
    'query redemptions: status 200': (r) => r.status === 200,
  });
  
  firestoreLatency.add(latency);
  errorRate.add(!success);
  sleep(1);
}

// Scenario 5: Batch Read (Merchants + Offers)
function batchRead() {
  const start = Date.now();
  const res1 = http.get(`${FIRESTORE_BASE}/merchants?pageSize=20`);
  const res2 = http.get(`${FIRESTORE_BASE}/offers?pageSize=20`);
  const latency = Date.now() - start;
  
  const success = check(res1, {
    'batch read merchants: status 200': (r) => r.status === 200,
  }) && check(res2, {
    'batch read offers: status 200': (r) => r.status === 200,
  });
  
  firestoreLatency.add(latency / 2); // Average per query
  errorRate.add(!success);
  sleep(1);
}

// Main test scenario - weighted mix
export default function () {
  const scenarios = [
    { weight: 40, fn: readOffers },       // 40% read offers
    { weight: 25, fn: readCustomer },     // 25% read customer
    { weight: 15, fn: writeCustomer },    // 15% write customer
    { weight: 10, fn: queryRedemptions }, // 10% query redemptions
    { weight: 10, fn: batchRead },        // 10% batch reads
  ];
  
  // Weighted random selection
  const rand = Math.random() * 100;
  let cumulative = 0;
  
  for (const scenario of scenarios) {
    cumulative += scenario.weight;
    if (rand <= cumulative) {
      scenario.fn();
      break;
    }
  }
}

// Setup
export function setup() {
  console.log('Firestore load test starting...');
  console.log(`Target: ${FIRESTORE_BASE}`);
  console.log(`VU Prefix: ${VU_PREFIX}`);
  
  // Verify Firestore is accessible
  const res = http.get(`${FIRESTORE_BASE}/customers?pageSize=1`);
  if (res.status !== 200) {
    throw new Error(`Firestore not accessible: ${res.status}`);
  }
  
  return { timestamp: new Date().toISOString() };
}

// Teardown
export function teardown(data) {
  console.log('Firestore load test completed');
  console.log('Started:', data.timestamp);
  console.log('Ended:', new Date().toISOString());
}
