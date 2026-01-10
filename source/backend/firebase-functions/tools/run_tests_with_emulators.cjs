#!/usr/bin/env node

/**
 * Start Firestore emulator, run Jest tests, and ensure cleanup.
 * Writes full combined output to /tmp/tests_full.log
 */

const { spawn } = require('child_process');
const net = require('net');
const fs = require('fs');
const path = require('path');

const LOG_PATH = '/tmp/tests_full.log';
const logStream = fs.createWriteStream(LOG_PATH, { flags: 'w' });

function log(line) {
  const msg = `[runner] ${line}`;
  console.log(msg);
  logStream.write(`${msg}\n`);
}

function teeStream(stream, prefix) {
  stream.on('data', (data) => {
    const text = data.toString();
    process.stdout.write(text);
    logStream.write(text.split('\n').map((l) => (l ? `${prefix}${l}` : '')).join('\n'));
  });
}

function waitForPort(host, port, retries = 60, delayMs = 500) {
  return new Promise((resolve, reject) => {
    let attempts = 0;

    const attempt = () => {
      const socket = net.createConnection({ host, port }, () => {
        socket.end();
        resolve();
      });

      socket.on('error', () => {
        socket.destroy();
        attempts += 1;
        if (attempts >= retries) {
          reject(new Error(`Emulator did not start on ${host}:${port} after ${attempts} attempts`));
        } else {
          setTimeout(attempt, delayMs);
        }
      });
    };

    attempt();
  });
}

async function run() {
  const cwd = process.cwd();
  log(`CWD: ${cwd}`);
  log(`Log path: ${LOG_PATH}`);

  const emulatorEnv = { ...process.env };
  const testEnv = {
    ...process.env,
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    GCLOUD_PROJECT: 'urbangen-test',
    GOOGLE_CLOUD_PROJECT: 'urbangen-test',
    NODE_ENV: 'test',
  };

  log('Starting Firestore emulator...');
  const emulatorProc = spawn(
    'npx',
    ['firebase', 'emulators:start', '--only', 'firestore', '--project', 'urbangen-test', '--config', '../../firebase.json'],
    {
      cwd,
      env: emulatorEnv,
      stdio: ['ignore', 'pipe', 'pipe'],
    }
  );

  teeStream(emulatorProc.stdout, '[emulator] ');
  teeStream(emulatorProc.stderr, '[emulator] ');

  let emulatorExited = false;
  emulatorProc.on('exit', (code, signal) => {
    emulatorExited = true;
    log(`Emulator exited (code=${code}, signal=${signal})`);
  });

  try {
    await waitForPort('127.0.0.1', 8080, 60, 500);
    log('Firestore emulator is ready on 127.0.0.1:8080');

    if (emulatorExited) {
      throw new Error('Emulator exited before tests could run');
    }

    log('Running Jest tests...');
    const testProc = spawn('npm', ['test'], { cwd, env: testEnv, stdio: ['ignore', 'pipe', 'pipe'] });
    teeStream(testProc.stdout, '[jest] ');
    teeStream(testProc.stderr, '[jest] ');

    const exitCode = await new Promise((resolve) => {
      testProc.on('exit', (code, signal) => {
        log(`Jest finished (code=${code}, signal=${signal})`);
        resolve(code ?? 1);
      });
    });

    if (exitCode !== 0) {
      throw new Error(`Jest failed with exit code ${exitCode}`);
    }

    return exitCode;
  } finally {
    if (!emulatorExited) {
      log('Shutting down emulator...');
      emulatorProc.kill('SIGINT');
      await new Promise((resolve) => emulatorProc.once('exit', resolve));
    } else {
      log('Emulator was already stopped.');
    }
  }
}

run()
  .then(() => {
    log('All tests passed with emulator.');
    logStream.end();
    process.exit(0);
  })
  .catch((err) => {
    log(`Error: ${err.message}`);
    logStream.end();
    process.exit(1);
  });
