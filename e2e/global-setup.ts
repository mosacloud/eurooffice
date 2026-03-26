import { spawnSync } from 'child_process';

const CONTAINER_NAME = 'euro-office-e2e';
const HOST_PORT = 8988;
const IMAGE = process.env.E2E_IMAGE ?? 'euro-office/documentserver:latest';
const TIMEOUT_MS = 5 * 60 * 1000;
const POLL_INTERVAL_MS = 3000;

async function waitForHealthcheck(url: string, timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      const text = await res.text();
      if (text.trim() === 'true') {
        console.log('[global-setup] healthcheck passed');
        return;
      }
    } catch {
      // Not ready yet — swallow connection errors and retry
    }
    await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL_MS));
  }
  throw new Error(`[global-setup] Timed out after ${timeoutMs / 1000}s waiting for healthcheck at ${url}`);
}

export default async function globalSetup(): Promise<void> {
  if (process.env.E2E_BASE_URL) {
    // Running against a pre-existing server — skip Docker
    console.log(`[global-setup] Using existing server at ${process.env.E2E_BASE_URL}`);
    return;
  }

  // Remove any leftover container from a previous run (idempotent)
  spawnSync('docker', ['rm', '-f', CONTAINER_NAME], { stdio: 'ignore' });

  console.log(`[global-setup] Starting container ${CONTAINER_NAME} from ${IMAGE}...`);
  const result = spawnSync(
    'docker',
    ['run', '-d', '--name', CONTAINER_NAME, '-p', `${HOST_PORT}:80`, '-e', 'EXAMPLE_ENABLED=true', IMAGE],
    { stdio: 'pipe', encoding: 'utf8' },
  );

  if (result.status !== 0) {
    throw new Error(`[global-setup] docker run failed:\n${result.stderr}`);
  }

  process.env.E2E_BASE_URL = `http://localhost:${HOST_PORT}`;
  // Signal teardown that we own the container
  process.env.E2E_DOCKER_MANAGED = 'true';

  console.log(`[global-setup] Container ID: ${result.stdout.trim().slice(0, 12)}`);
  console.log(`[global-setup] Waiting for healthcheck (up to ${TIMEOUT_MS / 1000}s)...`);

  await waitForHealthcheck(`${process.env.E2E_BASE_URL}/healthcheck`, TIMEOUT_MS);
}
