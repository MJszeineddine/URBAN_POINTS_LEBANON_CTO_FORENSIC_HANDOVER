#!/usr/bin/env node
/**
 * Load .env.local before any other modules are required
 * This ensures environment variables are available during build/deploy
 */

const fs = require('fs');
const path = require('path');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    
    // Skip empty lines and comments
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const [key, ...valueParts] = trimmed.split('=');
    if (!key || !valueParts.length) {
      continue;
    }

    const value = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
    
    // Only set if not already in environment
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

// Load in order: .env -> .env.local (overrides)
const dir = __dirname;
loadEnvFile(path.join(dir, '.env'));
loadEnvFile(path.join(dir, '.env.local'));
