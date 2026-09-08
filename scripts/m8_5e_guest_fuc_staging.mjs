#!/usr/bin/env node

import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const STAGING_ORIGIN = 'https://weddingos-staging.pages.dev';
const DEFAULT_RUNS = 5;
const PROFILES = {
  normal: { latency: 0, downloadThroughput: -1, uploadThroughput: -1, cpuRate: 1 },
  fixed4g: { latency: 150, downloadThroughput: 500_000, uploadThroughput: 375_000, cpuRate: 4 },
};

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function stagingConfiguration(environment = process.env) {
  const token = environment.STAGING_INVITATION_TOKEN?.trim();
  if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) {
    throw new Error('STAGING_INVITATION_TOKEN must contain a valid in-memory staging credential.');
  }
  const runs = Number(environment.STAGING_FUC_RUNS ?? DEFAULT_RUNS);
  if (!Number.isInteger(runs) || runs < 5 || runs > 20) {
    throw new Error('STAGING_FUC_RUNS must be an integer from 5 through 20.');
  }
  return {
    token,
    runs,
    chrome: environment.CHROME_PATH ?? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  };
}

export function summarize(values) {
  if (!Array.isArray(values) || values.length === 0) throw new Error('At least one timing is required.');
  const sorted = [...values].sort((left, right) => left - right);
  const sum = values.reduce((total, value) => total + value, 0);
  return {
    min_ms: sorted[0],
    median_ms: sorted[Math.floor(sorted.length / 2)],
    p90_ms: sorted[Math.ceil(sorted.length * 0.9) - 1],
    max_ms: sorted.at(-1),
    mean_ms: Math.round(sum / values.length),
  };
}

function summarizeRuns(runs) {
  const resolveValues = runs.map((run) => run.resolve_ms).filter((value) => value !== null);
  return {
    fuc: summarize(runs.map((run) => run.fuc_ms)),
    resolve: resolveValues.length > 0 ? summarize(resolveValues) : null,
  };
}

async function waitForJson(url, description) {
  let lastError;
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      const response = await fetch(url);
      if (response.ok) return response.json();
    } catch (error) {
      lastError = error;
    }
    await sleep(50);
  }
  throw new Error(`${description} did not become ready: ${lastError ?? 'unknown failure'}`);
}

function cdpClient(url) {
  const socket = new WebSocket(url);
  const pending = new Map();
  let nextId = 1;
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    const resolver = pending.get(message.id);
    if (!resolver) return;
    pending.delete(message.id);
    if (message.error) resolver.reject(new Error(message.error.message));
    else resolver.resolve(message.result);
  };
  return new Promise((resolve, reject) => {
    socket.onerror = () => reject(new Error('Chrome DevTools connection failed.'));
    socket.onopen = () => resolve({
      send(method, params = {}) {
        const id = nextId++;
        socket.send(JSON.stringify({ id, method, params }));
        return new Promise((resolveCommand, rejectCommand) => pending.set(id, {
          resolve: resolveCommand,
          reject: rejectCommand,
        }));
      },
      close() {
        socket.close();
      },
    });
  });
}

const fucObserver = `
  (() => {
    window.__weddingosFucStartedAt = performance.now();
    const capture = () => {
      if (document.querySelector('.invitation-card') && window.__weddingosFucMs == null) {
        window.__weddingosFucMs = performance.now() - window.__weddingosFucStartedAt;
      }
    };
    new MutationObserver(capture).observe(document, { childList: true, subtree: true });
    capture();
  })();
`;

async function measureRun(browserCdp, debuggingPort, token, profile) {
  const target = await browserCdp.send('Target.createTarget', { url: 'about:blank' });
  const pages = await waitForJson(`http://127.0.0.1:${debuggingPort}/json/list`, 'Chrome target list');
  const page = pages.find((entry) => entry.id === target.targetId);
  if (!page) throw new Error('Chrome target was not discoverable.');
  const cdp = await cdpClient(page.webSocketDebuggerUrl);
  try {
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');
    await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: profile.latency,
      downloadThroughput: profile.downloadThroughput,
      uploadThroughput: profile.uploadThroughput,
      connectionType: profile.latency > 0 ? 'cellular4g' : 'none',
    });
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: profile.cpuRate });
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: fucObserver });
    await cdp.send('Page.navigate', { url: `${STAGING_ORIGIN}/#/invite/${token}` });

    for (let poll = 0; poll < 300; poll++) {
      const result = await cdp.send('Runtime.evaluate', {
        expression: `(() => {
          const fuc = window.__weddingosFucMs;
          if (typeof fuc !== 'number') return null;
          const resources = performance.getEntriesByType('resource');
          const resolveEntry = resources.find((entry) => entry.name.endsWith('/v1/invitation/resolve'));
          return {
            fuc_ms: Math.round(fuc),
            resolve_ms: resolveEntry ? Math.round(resolveEntry.duration) : null,
            transfer_bytes: resources.reduce((total, entry) => total + (entry.transferSize || 0), 0),
            ready_state: document.readyState,
          };
        })()`,
        returnByValue: true,
      });
      if (result.result.value) return result.result.value;
      await sleep(50);
    }
    throw new Error('Invitation FUC did not render within 15 seconds.');
  } finally {
    await browserCdp.send('Target.closeTarget', { targetId: target.targetId });
    cdp.close();
  }
}

export async function runBenchmark(config = stagingConfiguration()) {
  const debuggingPort = 9300 + Math.floor(Math.random() * 500);
  const chromeProfile = await mkdtemp(join(tmpdir(), 'weddingos-m8-5e-chrome-'));
  const browser = spawn(config.chrome, [
    '--headless=new',
    `--remote-debugging-port=${debuggingPort}`,
    `--user-data-dir=${chromeProfile}`,
    '--no-first-run',
    '--no-default-browser-check',
    'about:blank',
  ], { stdio: 'ignore', windowsHide: true });

  try {
    const version = await waitForJson(`http://127.0.0.1:${debuggingPort}/json/version`, 'Chrome DevTools');
    const browserCdp = await cdpClient(version.webSocketDebuggerUrl);
    const results = {};
    try {
      for (const [name, profile] of Object.entries(PROFILES)) {
        results[name] = [];
        for (let run = 0; run < config.runs; run++) {
          results[name].push(await measureRun(browserCdp, debuggingPort, config.token, profile));
        }
      }
    } finally {
      browserCdp.close();
    }

    const fixed4gSummary = summarize(results.fixed4g.map((run) => run.fuc_ms));
    const output = {
      status: fixed4gSummary.p90_ms < 3000 ? 'PASS' : 'FAIL',
      environment: STAGING_ORIGIN,
      fuc_condition: '.invitation-card rendered after deployed invitation resolve',
      cold_cache: true,
      service_worker: 'none',
      profiles: {
        normal: 'Chrome unthrottled network, CPU 1x',
        fixed4g: 'Chrome CDP synthetic 4G: 150ms latency, 4Mbps download, 3Mbps upload, CPU 4x',
      },
      target_p90_ms: 3000,
      p90_method: 'nearest-rank; with 5 runs p90 equals the maximum sample',
      runs: results,
      summary: Object.fromEntries(
        Object.entries(results).map(([name, runs]) => [name, summarizeRuns(runs)]),
      ),
    };
    console.log(JSON.stringify(output, null, 2));
    if (output.status !== 'PASS') process.exitCode = 1;
    return output;
  } finally {
    browser.kill();
    await rm(chromeProfile, { recursive: true, force: true, maxRetries: 4, retryDelay: 200 }).catch(() => {});
  }
}

const isMainModule = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMainModule) {
  runBenchmark().catch((error) => {
    console.error(error instanceof Error ? error.message : 'Staging FUC benchmark failed.');
    process.exitCode = 1;
  });
}
