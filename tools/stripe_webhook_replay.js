#!/usr/bin/env node
/**
 * Stripe Webhook Replay Tool
 * 
 * Sends sample Stripe webhook events to the stripeWebhook function for testing.
 * Can target local Firebase emulator or production endpoint.
 * 
 * Usage:
 *   node stripe_webhook_replay.js <event_file> [--local|--production] [--skip-signature]
 * 
 * Examples:
 *   node stripe_webhook_replay.js stripe_samples/checkout_session_completed.json --local
 *   node stripe_webhook_replay.js stripe_samples/invoice_payment_succeeded.json --production
 */

const fs = require('fs');
const https = require('https');
const http = require('http');

// ============================================================================
// CONFIGURATION
// ============================================================================

const PRODUCTION_URL = 'https://us-central1-urbangenspark.cloudfunctions.net/stripeWebhook';
const LOCAL_URL = 'http://localhost:5001/urbangenspark/us-central1/stripeWebhook';

// Parse command line arguments
const args = process.argv.slice(2);
const eventFile = args[0];
const targetMode = args.find(arg => arg === '--local' || arg === '--production') || '--local';
const skipSignature = args.includes('--skip-signature');

if (!eventFile) {
  console.error('Usage: node stripe_webhook_replay.js <event_file> [--local|--production] [--skip-signature]');
  console.error('');
  console.error('Examples:');
  console.error('  node stripe_webhook_replay.js stripe_samples/checkout_session_completed.json --local');
  console.error('  node stripe_webhook_replay.js stripe_samples/invoice_payment_succeeded.json --production');
  process.exit(1);
}

// ============================================================================
// LOAD EVENT PAYLOAD
// ============================================================================

let eventPayload;
try {
  const rawData = fs.readFileSync(eventFile, 'utf8');
  eventPayload = JSON.parse(rawData);
  console.log(`✅ Loaded event: ${eventPayload.type}`);
} catch (error) {
  console.error(`❌ Error loading event file: ${error.message}`);
  process.exit(1);
}

// ============================================================================
// SEND WEBHOOK
// ============================================================================

const targetUrl = targetMode === '--production' ? PRODUCTION_URL : LOCAL_URL;
const url = new URL(targetUrl);
const isHttps = url.protocol === 'https:';
const client = isHttps ? https : http;

console.log(`🎯 Target: ${targetUrl}`);
console.log(`🔐 Signature verification: ${skipSignature ? 'SKIPPED' : 'REQUIRED'}`);
console.log('');

const payload = JSON.stringify(eventPayload);

const options = {
  hostname: url.hostname,
  port: url.port || (isHttps ? 443 : 80),
  path: url.pathname,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
};

// Add mock Stripe signature if not skipping
// NOTE: In production, Stripe generates real signatures. This is a mock for local testing.
if (!skipSignature) {
  // For local testing, use a mock signature that matches webhook_secret pattern
  // In production, you'd need to generate a real Stripe signature
  options.headers['stripe-signature'] = 't=1234567890,v1=mockSignatureForLocalTesting123456789';
  console.warn('⚠️  Using MOCK signature. Production webhooks will fail signature verification.');
  console.warn('⚠️  For production testing, use Stripe Dashboard "Send test webhook" instead.');
  console.log('');
}

const req = client.request(options, (res) => {
  console.log(`📡 Response Status: ${res.statusCode} ${res.statusMessage}`);
  
  let responseBody = '';
  res.on('data', (chunk) => {
    responseBody += chunk;
  });
  
  res.on('end', () => {
    console.log('');
    console.log('📄 Response Body:');
    console.log(responseBody || '(empty)');
    console.log('');
    
    if (res.statusCode === 200) {
      console.log('✅ Webhook processed successfully');
    } else {
      console.log('❌ Webhook failed');
      process.exit(1);
    }
  });
});

req.on('error', (error) => {
  console.error(`❌ Request error: ${error.message}`);
  process.exit(1);
});

req.write(payload);
req.end();
