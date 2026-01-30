/**
 * Validation Middleware for Cloud Functions
 * Integrates Zod validation and rate limiting
 */

import { CallableContext } from 'firebase-functions/v1/https';
import { z } from 'zod';
import { isRateLimited, RATE_LIMITS } from '../utils/rateLimiter';
import { validateInput } from '../validation/schemas';

/**
 * Validation error response
 */
export interface ValidationError {
  error: string;
  code: 'invalid-argument' | 'resource-exhausted' | 'unauthenticated';
  details?: unknown;
}

/**
 * Validate and rate limit wrapper for Cloud Functions
 */
export async function validateAndRateLimit<T>(
  data: unknown,
  context: CallableContext,
  schema: z.ZodSchema<T>,
  operation: string
): Promise<T | ValidationError> {
  // 1. Authentication check
  if (!context.auth) {
    return {
      error: 'Authentication required',
      code: 'unauthenticated'
    };
  }

  const userId = context.auth.uid;

  // 2. Rate limiting check
  const rateLimitConfig = RATE_LIMITS[operation as keyof typeof RATE_LIMITS];
  const isLimited = await isRateLimited(userId, operation, rateLimitConfig);

  if (isLimited) {
    return {
      error: `Rate limit exceeded for ${operation}. Please try again later.`,
      code: 'resource-exhausted'
    };
  }

  // 3. Input validation
  try {
    const validated = validateInput(schema, data);
    return validated;
  } catch (error) {
    if (error instanceof z.ZodError) {
      return {
        error: 'Invalid input data',
        code: 'invalid-argument',
        details: error.errors
      };
    }
    throw error;
  }
}

/**
 * Check if response is a validation error
 */
export function isValidationError(response: unknown): response is ValidationError {
  return (
    typeof response === 'object' &&
    response !== null &&
    'error' in response &&
    'code' in response
  );
}
