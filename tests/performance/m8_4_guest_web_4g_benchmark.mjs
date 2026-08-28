import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const chrome = process.env.CHROME_PATH ?? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9226;
const vitePort = 4173;
const appUrl = `http://127.0.0.1:${vitePort}/#/invite/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345`;
const profile = { latency: 150, downloadThroughput: 500_000, uploadThroughput: 375_000 };

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function run(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    child.on('error', reject);
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`Build process exited ${code}.`)));
  });
}

async function waitFor(url, description) {
  let lastError;
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      const response = await fetch(url);
      if (response.ok) return response;
    } catch (error) {
      lastError = error;
    }
    await sleep(100);
  }
  throw new Error(`${description} did not become ready: ${lastError ?? 'unknown failure'}`);
}

async function removeTemporary(path) {
  try {
    await rm(path, { recursive: true, force: true, maxRetries: 4, retryDelay: 200 });
  } catch {
    // Chrome may retain a Crashpad file briefly; the directory is outside the repository.
  }
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
        return new Promise((resolveCommand, rejectCommand) => pending.set(id, { resolve: resolveCommand, reject: rejectCommand }));
      },
      close() { socket.close(); },
    });
  });
}

const mockedInvitation = {
  ok: true,
  invitation: {
    wedding: { name: 'M8.4 Performance Wedding', public_contact_phone: null, public_contact_email: null },
    party: { display_name: 'Gia đình benchmark', invited_count: 2 },
    events: [{ id: '84000000-0000-4000-8000-000000000010', name: 'Lễ cưới', date_precision: 'EXACT', exact_date: '2026-12-01', expected_year: null, expected_month: null, start_time: '18:00', location: 'Benchmark Hall', map_link: 'https://maps.example/benchmark', rsvp_ready: true }],
    rsvp: { summary: 'Chưa phản hồi', event_responses: [], warnings: [], guest_message: null, dietary_info: null, companion_names: null, note: null },
    vietqr: { available: false },
    can_submit_rsvp: true,
    cover_photo_signed_url: null,
  },
};

const bootstrap = `
  (() => {
    const startedAt = performance.now();
    const payload = ${JSON.stringify(mockedInvitation)};
    const originalFetch = window.fetch.bind(window);
    window.fetch = (input, init) => String(input).includes('/v1/invitation/resolve')
      ? Promise.resolve(new Response(JSON.stringify(payload), { status: 200, headers: { 'content-type': 'application/json' } }))
      : originalFetch(input, init);
    const observer = new MutationObserver(() => {
      if (document.querySelector('.invitation-card') && !window.__m8FirstUsefulContentMs) {
        window.__m8FirstUsefulContentMs = performance.now() - startedAt;
        observer.disconnect();
      }
    });
    observer.observe(document, { childList: true, subtree: true });
  })();
`;

const chromeProfile = await mkdtemp(join(tmpdir(), 'weddingos-m8-4-chrome-'));
const buildDirectory = await mkdtemp(join(tmpdir(), 'weddingos-m8-4-build-'));
const guestWebDirectory = fileURLToPath(new URL('../../guest_web/', import.meta.url));
await run(process.execPath, [join(guestWebDirectory, 'node_modules', 'vite', 'bin', 'vite.js'), 'build', '--outDir', buildDirectory], {
  cwd: guestWebDirectory, stdio: 'ignore', windowsHide: true,
});
const server = createServer(async (request, response) => {
  const requestedPath = request.url === '/' ? '/index.html' : request.url.split('?')[0];
  const path = join(buildDirectory, requestedPath);
  try {
    const file = await readFile(path);
    response.writeHead(200, { 'content-type': path.endsWith('.js') ? 'text/javascript' : path.endsWith('.css') ? 'text/css' : 'text/html' });
    response.end(file);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(vitePort, '127.0.0.1', resolve));
const browser = spawn(chrome, [
  '--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${chromeProfile}`,
  '--no-first-run', '--no-default-browser-check', 'about:blank',
], { stdio: 'ignore', windowsHide: true });

try {
  await waitFor(`http://127.0.0.1:${vitePort}`, 'temporary production bundle server');
  const version = await (await waitFor(`http://127.0.0.1:${port}/json/version`, 'Chrome DevTools')).json();
  const browserCdp = await cdpClient(version.webSocketDebuggerUrl);
  const values = [];

  for (let iteration = 0; iteration < 3; iteration++) {
    const target = await browserCdp.send('Target.createTarget', { url: 'about:blank' });
    const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const page = pages.find((entry) => entry.id === target.targetId);
    const cdp = await cdpClient(page.webSocketDebuggerUrl);
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');
    await cdp.send('Network.clearBrowserCache');
    await cdp.send('Network.emulateNetworkConditions', { offline: false, ...profile, connectionType: 'cellular4g' });
    await cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: bootstrap });
    await cdp.send('Page.navigate', { url: appUrl });

    let fuc;
    for (let poll = 0; poll < 100; poll++) {
      const result = await cdp.send('Runtime.evaluate', { expression: 'window.__m8FirstUsefulContentMs ?? null', returnByValue: true });
      fuc = result.result.value;
      if (typeof fuc === 'number') break;
      await sleep(50);
    }
    if (typeof fuc !== 'number') {
      const diagnostic = await cdp.send('Runtime.evaluate', {
        expression: 'JSON.stringify({ text: document.body.innerText, href: location.href, resources: performance.getEntriesByType(\'resource\').map((entry) => entry.name) })',
        returnByValue: true,
      });
      throw new Error(`Guest Web invitation content did not render: ${diagnostic.result.value}`);
    }
    values.push(Math.round(fuc));
    await cdp.send('Target.closeTarget', { targetId: target.targetId });
    cdp.close();
  }
  browserCdp.close();
  const sorted = [...values].sort((left, right) => left - right);
  console.log(JSON.stringify({
    status: 'PASS',
    profile: 'Chrome CDP fixed 4G: 150ms latency, 4Mbps download, 3Mbps upload',
    fixture: 'synthetic invitation DTO; built Guest Web bundle; resolve transport measured separately',
    runsMs: values,
    medianMs: sorted[Math.floor(sorted.length / 2)],
    targetMs: 3000,
  }));
} finally {
  browser.kill();
  server.close();
  await removeTemporary(chromeProfile);
  await removeTemporary(buildDirectory);
}
