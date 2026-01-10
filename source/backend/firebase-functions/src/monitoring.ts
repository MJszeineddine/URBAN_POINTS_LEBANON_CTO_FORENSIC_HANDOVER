/**
 * Centralized Error Tracking and Monitoring
 * 
 * Integrates Sentry for error tracking and provides monitoring utilities.
 * Captures exceptions, performance traces, and custom events.
 */

import * as Sentry from '@sentry/node';
import Logger from './logger';

const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
const SENTRY_DSN = process.env.SENTRY_DSN;

/**
 * Initialize Sentry for error tracking
 */
export function initializeMonitoring(): void {
  if (!isEmulator && SENTRY_DSN) {
    Sentry.init({
      dsn: SENTRY_DSN,
      environment: process.env.FIREBASE_CONFIG ? 'production' : 'staging',
      tracesSampleRate: 0.1, // 10% of transactions
      integrations: [
        new Sentry.Integrations.Http({ tracing: true }),
      ],
      beforeSend(event, hint) {
        // Filter out expected errors
        const error = hint.originalException;
        if (error && typeof error === 'object' && 'code' in error) {
          const code = (error as any).code;
          // Don't report expected auth errors
          if (code === 'unauthenticated' || code === 'permission-denied') {
            return null;
          }
        }
        return event;
      }
    });
    Logger.info('Sentry monitoring initialized', { environment: Sentry.getCurrentHub().getClient()?.getOptions().environment });
  } else if (!isEmulator) {
    Logger.warn('Sentry DSN not configured - error tracking disabled');
  } else {
    Logger.debug('Emulator mode - Sentry disabled');
  }
}

/**
 * Capture exception with context
 */
export function captureException(error: Error, context?: Record<string, any>): void {
  Logger.error('Exception captured', error, context);
  
  if (!isEmulator && SENTRY_DSN) {
    Sentry.captureException(error, {
      tags: context?.tags,
      extra: context
    });
  }
}

/**
 * Capture custom message/event
 */
export function captureMessage(message: string, level: Sentry.SeverityLevel = 'info', context?: Record<string, any>): void {
  Logger.info(message, context);
  
  if (!isEmulator && SENTRY_DSN) {
    Sentry.captureMessage(message, {
      level,
      tags: context?.tags,
      extra: context
    });
  }
}

/**
 * Start performance transaction
 */
export function startTransaction(name: string, operation: string): Sentry.Transaction | null {
  if (!isEmulator && SENTRY_DSN) {
    return Sentry.startTransaction({
      name,
      op: operation
    });
  }
  return null;
}

/**
 * Track performance metric
 */
export function trackPerformance(metricName: string, durationMs: number, context?: Record<string, any>): void {
  Logger.metric(metricName, durationMs, 'ms', context);
  
  if (!isEmulator && SENTRY_DSN) {
    Sentry.captureMessage(`Performance: ${metricName}`, {
      level: 'info',
      tags: {
        metric_name: metricName,
        duration_ms: durationMs.toString(),
        ...context?.tags
      },
      extra: context
    });
  }
}

/**
 * Set user context for error tracking
 */
export function setUserContext(userId: string, email?: string, role?: string): void {
  if (!isEmulator && SENTRY_DSN) {
    Sentry.setUser({
      id: userId,
      email,
      role
    });
  }
}

/**
 * Clear user context
 */
export function clearUserContext(): void {
  if (!isEmulator && SENTRY_DSN) {
    Sentry.setUser(null);
  }
}

/**
 * Middleware wrapper for Cloud Functions to track errors and performance
 */
export function monitorFunction<T extends (...args: any[]) => Promise<any>>(
  functionName: string,
  handler: T
): T {
  return (async (...args: any[]) => {
    const startTime = Date.now();
    const transaction = startTransaction(functionName, 'cloud-function');
    
    try {
      Logger.info(`Starting function: ${functionName}`);
      const result = await handler(...args);
      
      const duration = Date.now() - startTime;
      Logger.metric(`${functionName}.duration`, duration, 'ms', { status: 'success' });
      
      if (transaction) {
        transaction.setStatus('ok');
        transaction.finish();
      }
      
      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      Logger.error(`Function failed: ${functionName}`, error as Error, { duration });
      
      captureException(error as Error, {
        functionName,
        duration,
        args: args.length > 0 ? JSON.stringify(args[0]) : undefined
      });
      
      if (transaction) {
        transaction.setStatus('internal_error');
        transaction.finish();
      }
      
      throw error;
    }
  }) as T;
}

/**
 * Alert configurations for critical issues
 */
export interface AlertConfig {
  errorRateThreshold: number;      // errors per minute
  latencyP95Threshold: number;      // milliseconds
  functionFailureThreshold: number; // failures per minute
}

export const DEFAULT_ALERT_CONFIG: AlertConfig = {
  errorRateThreshold: 10,      // 10 errors/min triggers alert
  latencyP95Threshold: 5000,   // 5s p95 latency triggers alert
  functionFailureThreshold: 5  // 5 failures/min triggers alert
};

/**
 * Track alert-worthy metrics
 */
export function trackAlertMetric(metricType: 'error' | 'latency' | 'failure', value: number, context?: Record<string, any>): void {
  const config = DEFAULT_ALERT_CONFIG;
  let shouldAlert = false;
  
  switch (metricType) {
    case 'error':
      shouldAlert = value >= config.errorRateThreshold;
      break;
    case 'latency':
      shouldAlert = value >= config.latencyP95Threshold;
      break;
    case 'failure':
      shouldAlert = value >= config.functionFailureThreshold;
      break;
  }
  
  if (shouldAlert) {
    Logger.security(
      `Alert threshold exceeded: ${metricType} = ${value}`,
      'high',
      { ...context, metricType, value, threshold: config[`${metricType}Threshold` as keyof AlertConfig] }
    );
    
    captureMessage(
      `ALERT: ${metricType} threshold exceeded`,
      'warning',
      { ...context, metricType, value }
    );
  }
}

export default {
  initializeMonitoring,
  captureException,
  captureMessage,
  startTransaction,
  trackPerformance,
  setUserContext,
  clearUserContext,
  monitorFunction,
  trackAlertMetric
};
