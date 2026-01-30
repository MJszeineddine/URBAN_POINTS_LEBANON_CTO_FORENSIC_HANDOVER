#!/usr/bin/env node
// Phase 3 CI runner: starts Firestore emulator (IPv4), runs phase3 Jest tests, cleans up.

const { spawn, exec } = require('child_process');
const net = require('net');
const fs = require('fs');
const path = require('path');
const os = require('os');

const ENV = {
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  GCLOUD_PROJECT: 'urbangenspark-test',
  GOOGLE_CLOUD_PROJECT: 'urbangenspark-test',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
};

const PORTS = [8080, 9150, 4400, 4000, 9099, 4500];
const EMULATOR_LOG = '/tmp/phase3_emulator.log';
const TEST_LOG = '/tmp/phase3_tests.log';

function logEmu(msg) {
  const line = `[emu] ${msg}`;
  console.log(line);
  fs.appendFileSync(EMULATOR_LOG, line + '\n');
}

function logTest(line) {
  fs.appendFileSync(TEST_LOG, line);
}

function killPorts() {
  return Promise.all(
    PORTS.map(
      (port) =>
        new Promise((resolve) => {
          exec(`lsof -ti tcp:${port} || true`, (err, stdout) => {
            if (!stdout) return resolve();
            const pids = stdout
              .split('\n')
              .map((s) => s.trim())
              .filter(Boolean);
            if (pids.length === 0) return resolve();
            exec(`kill -9 ${pids.join(' ')}`, () => resolve());
          });
        })
    )
  );
}

function waitForPort(host, port, timeoutMs = 60000, intervalMs = 1000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const attempt = () => {
      const sock = net.createConnection({ host, port }, () => {
        sock.end();
        resolve();
      });
      sock.on('error', () => {
        sock.destroy();
        if (Date.now() - start >= timeoutMs) {
          reject(new Error(`Timeout waiting for ${host}:${port}`));
        } else {
          setTimeout(attempt, intervalMs);
        }
      });
    };
    attempt();
  });
}

function findEmulatorJar() {
  const cacheDir = path.join(os.homedir(), '.cache', 'firebase', 'emulators');
  if (!fs.existsSync(cacheDir)) {
    return null;
  }
  const files = fs.readdirSync(cacheDir).filter(f => f.startsWith('cloud-firestore-emulator-') && f.endsWith('.jar'));
  if (files.length === 0) return null;
  files.sort().reverse(); // highest version first
  return path.join(cacheDir, files[0]);
}

async function startEmulator() {
  await killPorts();
  
  const jarPath = findEmulatorJar();
  if (!jarPath) {
    console.error('ERROR: Firestore emulator JAR not found in ~/.cache/firebase/emulators/');
    console.error('Download it by running once:');
    console.error('  npx -y firebase-tools@12.9.1 emulators:start --only firestore --project urbangenspark-test');
    console.error('Then Ctrl+C after download completes and re-run tests.');
    throw new Error('Emulator JAR not cached');
  }

  const javaArgs = [
    '-Dgoogle.cloud_firestore.debug_log_level=FINE',
    '-Duser.language=en',
    '-jar',
    jarPath,
    '--host', '127.0.0.1',
    '--port', '8080',
    '--websocket_port', '9150',
    '--project_id', 'urbangenspark-test',
    '--single_project_mode', 'true',
  ];
  
  logEmu(`Starting emulator: java ${javaArgs.join(' ')}`);
  const child = spawn('java', javaArgs, {
    env: { ...process.env, ...ENV },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (d) => logEmu(d.toString().trimEnd()));
  child.stderr.on('data', (d) => logEmu(d.toString().trimEnd()));

  let exited = false;
  child.on('exit', (code) => {
    exited = true;
    logEmu(`Emulator exited with code ${code}`);
  });

  await waitForPort('127.0.0.1', 8080).catch((err) => {
    if (exited) {
      throw new Error('Emulator process exited before becoming ready');
    }
    throw err;
  });
  logEmu('Emulator ready on 127.0.0.1:8080');

  return child;
}

async function runJest() {
  return new Promise((resolve) => {
    const args = [
      'jest',
      '--runInBand',
      '--coverage',
      '--verbose',
      '--testPathPattern',
      'src/__tests__/phase3\.test\.ts',
    ];
    const child = spawn('npx', args, {
      env: { ...process.env, ...ENV },
      cwd: path.join(__dirname, '..'),
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    child.stdout.on('data', (d) => {
      const text = d.toString();
      process.stdout.write(text);
      logTest(text);
    });
    child.stderr.on('data', (d) => {
      const text = d.toString();
      process.stderr.write(text);
      logTest(text);
    });
    child.on('exit', (code) => resolve(code ?? 1));
  });
}

(async () => {
  Object.entries(ENV).forEach(([k, v]) => (process.env[k] = v));
  fs.writeFileSync(EMULATOR_LOG, '');
  fs.writeFileSync(TEST_LOG, '');

  let emulatorProc;
  try {
    emulatorProc = await startEmulator();
  } catch (err) {
    console.error('Failed to start emulator:', err.message);
    await killPorts();
    process.exit(1);
  }

  const exitCode = await runJest();

  if (emulatorProc && emulatorProc.pid) {
    try {
      process.kill(emulatorProc.pid, 'SIGTERM');
    } catch (_) {
      // ignore
    }
  }
  await killPorts();
  process.exit(exitCode);
})();
