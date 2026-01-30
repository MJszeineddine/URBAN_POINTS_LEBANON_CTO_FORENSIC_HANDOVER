/**
 * Minimal unit test to ensure Jest runs at least one test.
 * This test is pure and does not require network or emulators.
 */

// Ensure required env is set within test process (dummy value only for test scope)
if (!process.env.QR_TOKEN_SECRET) {
  process.env.QR_TOKEN_SECRET = 'DUMMY_TEST_ONLY_DO_NOT_USE_IN_PROD';
}

import { healthPing, sum } from '../utils/healthcheck';

describe('healthcheck utils', () => {
  it('healthPing returns ok', () => {
    expect(healthPing()).toBe('ok');
  });

  it('sum adds two numbers', () => {
    expect(sum(2, 3)).toBe(5);
  });
});
