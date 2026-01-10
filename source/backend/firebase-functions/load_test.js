// k6 Load Test for Urban Points Lebanon Backend
// PHASE 3: LOAD/STRESS TESTING
// Timestamp: 2025-12-29
// Target: Firebase Cloud Functions Emulator

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration profiles
export const options = {
  stages: [
    // Profile 1: Warmup
    { duration: '30s', target: 10 },   // Ramp up to 10 users
    // Profile 2: Normal Load
    { duration: '1m', target: 50 },    // Ramp to 50 users
    { duration: '2m', target: 50 },    // Hold at 50 users
    // Profile 3: Stress Test
    { duration: '30s', target: 100 },  // Spike to 100 users
    { duration: '1m', target: 100 },   // Hold at 100 users
    // Profile 4: Cool Down
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    // Performance thresholds
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.05'],    // Error rate under 5%
    errors: ['rate<0.05'],             // Custom error rate under 5%
  },
};

// Test data
const BASE_URL = 'http://localhost:5001/urbangenspark-test/us-central1';
const TEST_USER_ID = 'load_test_user_001';
const TEST_MERCHANT_ID = 'load_test_merchant_001';
const TEST_OFFER_ID = 'load_test_offer_001';

// Scenario 1: Browse Offers
function browseOffers() {
  const res = http.get(`${BASE_URL}/getOffers`);
  
  const success = check(res, {
    'browse offers: status 200': (r) => r.status === 200,
    'browse offers: has offers': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.offers && Array.isArray(body.offers);
      } catch {
        return false;
      }
    },
  });
  
  errorRate.add(!success);
  sleep(1);
}

// Scenario 2: Redeem Points
function redeemPoints() {
  const payload = JSON.stringify({
    customer_id: TEST_USER_ID,
    merchant_id: TEST_MERCHANT_ID,
    offer_id: TEST_OFFER_ID,
    points_cost: 100,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const res = http.post(`${BASE_URL}/redeemPoints`, payload, params);
  
  const success = check(res, {
    'redeem points: status in [200,400]': (r) => r.status === 200 || r.status === 400,
    'redeem points: has response': (r) => r.body && r.body.length > 0,
  });
  
  errorRate.add(!success);
  sleep(2);
}

// Scenario 3: Generate QR Token
function generateQR() {
  const payload = JSON.stringify({
    userId: TEST_USER_ID,
    offerId: TEST_OFFER_ID,
    merchantId: TEST_MERCHANT_ID,
    deviceHash: `device_${__VU}_${__ITER}`,
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer test_token_${TEST_USER_ID}`,
    },
  };
  
  const res = http.post(`${BASE_URL}/generateQRToken`, payload, params);
  
  const success = check(res, {
    'generate QR: status in [200,401,400]': (r) => [200, 401, 400].includes(r.status),
  });
  
  errorRate.add(!success);
  sleep(1);
}

// Scenario 4: Check Subscription Status
function checkSubscription() {
  const res = http.get(`${BASE_URL}/getCustomer?userId=${TEST_USER_ID}`);
  
  const success = check(res, {
    'subscription check: status in [200,404]': (r) => r.status === 200 || r.status === 404,
  });
  
  errorRate.add(!success);
  sleep(1);
}

// Main test scenario - weighted mix of operations
export default function () {
  const scenarios = [
    { weight: 50, fn: browseOffers },       // 50% browse offers
    { weight: 25, fn: redeemPoints },       // 25% redeem points
    { weight: 15, fn: generateQR },         // 15% generate QR
    { weight: 10, fn: checkSubscription },  // 10% check subscription
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

// Setup function - runs once per VU
export function setup() {
  console.log('Load test starting...');
  console.log(`Target: ${BASE_URL}`);
  console.log(`Test User: ${TEST_USER_ID}`);
  return { timestamp: new Date().toISOString() };
}

// Teardown function - runs once at end
export function teardown(data) {
  console.log('Load test completed at:', new Date().toISOString());
  console.log('Started at:', data.timestamp);
}
