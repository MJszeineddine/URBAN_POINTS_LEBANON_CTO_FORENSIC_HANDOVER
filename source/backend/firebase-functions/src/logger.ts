/**
 * Centralized Structured Logging for Urban Points Lebanon
 * 
 * Uses Winston for structured logging with Cloud Logging integration.
 * Provides consistent log formatting, severity levels, and context tracking.
 */

import * as winston from 'winston';
import { LoggingWinston } from '@google-cloud/logging-winston';

const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';

/**
 * Safe Cloud Logging transport initialization
 * Falls back to console if credentials are missing
 */
function createProductionTransports(): winston.transport[] {
  try {
    return [
      new LoggingWinston({
        projectId: process.env.GCLOUD_PROJECT,
        logName: 'urban-points-functions'
      })
    ];
  } catch (error) {
    // Fallback to console if Cloud Logging fails (e.g., missing credentials during deployment analysis)
    console.warn('⚠️ Cloud Logging unavailable, falling back to console:', error instanceof Error ? error.message : 'Unknown error');
    return [
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.json()
        )
      })
    ];
  }
}

/**
 * Create Winston logger with Cloud Logging transport (production)
 * or console transport (emulator/development)
 */
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'urban-points-lebanon-functions',
    environment: isEmulator ? 'development' : 'production'
  },
  transports: isEmulator
    ? [
        // Console transport for local development
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          )
        })
      ]
    : createProductionTransports()
});

/**
 * Log context interface for structured logging
 */
export interface LogContext {
  userId?: string;
  merchantId?: string;
  functionName?: string;
  requestId?: string;
  customerId?: string;
  transactionId?: string;
  offerId?: string;
  [key: string]: any;
}

/**
 * Enhanced logging utility with structured context
 */
export class Logger {
  /**
   * Log informational message
   */
  static info(message: string, context?: LogContext): void {
    logger.info(message, context);
  }

  /**
   * Log warning message
   */
  static warn(message: string, context?: LogContext): void {
    logger.warn(message, context);
  }

  /**
   * Log error with full stack trace
   */
  static error(message: string, error?: Error, context?: LogContext): void {
    logger.error(message, {
      ...context,
      error: error ? {
        message: error.message,
        stack: error.stack,
        name: error.name
      } : undefined
    });
  }

  /**
   * Log debug message (only in development)
   */
  static debug(message: string, context?: LogContext): void {
    logger.debug(message, context);
  }

  /**
   * Log performance metric
   */
  static metric(metricName: string, value: number, unit: string, context?: LogContext): void {
    logger.info('Performance metric', {
      ...context,
      metric: {
        name: metricName,
        value,
        unit
      }
    });
  }

  /**
   * Log business event (redemptions, points awards, etc.)
   */
  static event(eventType: string, eventData: any, context?: LogContext): void {
    logger.info('Business event', {
      ...context,
      eventType,
      eventData
    });
  }

  /**
   * Log security event (auth failures, suspicious activity)
   */
  static security(message: string, severity: 'low' | 'medium' | 'high' | 'critical', context?: LogContext): void {
    logger.warn(`[SECURITY-${severity.toUpperCase()}] ${message}`, {
      ...context,
      securitySeverity: severity,
      alertType: 'security'
    });
  }
}

export default Logger;
