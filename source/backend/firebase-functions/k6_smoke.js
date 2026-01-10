import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    smoke: {
      executor: 'constant-vus',
      vus: 5,
      duration: '1m',
      tags: { test_type: 'smoke' },
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500'],
    errors: ['rate<0.1'],
  },
};

const FIRESTORE_HOST = 'http://localhost:8080';

export default function () {
  // Test 1: Query offers
  const offersRes = http.get(`${FIRESTORE_HOST}/v1/projects/urbangenspark-test/databases/(default)/documents/offers`);
  check(offersRes, {
    'offers query status 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  // Test 2: Query customers
  const customersRes = http.get(`${FIRESTORE_HOST}/v1/projects/urbangenspark-test/databases/(default)/documents/customers`);
  check(customersRes, {
    'customers query status 200': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(1);
}
