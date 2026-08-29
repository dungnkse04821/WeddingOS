import { beginWeddingDelete, cleanupWeddingStorage, DELETE_BODY_LIMIT_BYTES, type StorageEntry } from './index.ts';

Deno.test('rejects non-POST without invoking trusted services', async () => {
  const response = await beginWeddingDelete(
    new Request('http://local', { method: 'GET' }),
  );
  if (response.status !== 405) throw new Error('expected 405');
});

Deno.test('denies missing bearer token', async () => {
  const response = await beginWeddingDelete(
    new Request('http://local', { method: 'POST', body: '{}' }),
  );
  if (response.status !== 401) throw new Error('expected 401');
});

Deno.test('uses verified auth id, cleans only the authoritative prefix, and finalizes after a fresh empty list', async () => {
  const original = globalThis.fetch;
  const calls: Array<{ url: string; body?: Record<string, unknown> }> = [];
  const pages = new Map<string, StorageEntry[][]>([
    ['weddings/wedding-a/', [[{ name: 'cover.webp', id: 'one' }, {
      name: 'nested',
    }], []]],
    ['weddings/wedding-a/nested/', [[{ name: 'second.webp', id: 'two' }], []]],
  ]);
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input, init) => {
    const url = String(input);
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    calls.push({ url, body });
    if (String(input).includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/rpc/finalize_wedding_delete')) {
      return new Response(JSON.stringify({ status: 'DELETED' }));
    }
    if (url.includes('/object/list/')) {
      return new Response(
        JSON.stringify(pages.get(String(body?.prefix))?.shift() ?? []),
      );
    }
    if (url.includes('/object/wedding_media')) {
      return new Response(JSON.stringify({}));
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({
          wedding_id: 'wedding-a',
          prefix: 'weddings/wedding-b/',
          actor_user_id: 'attacker',
        }),
      }),
    );
    if (
      response.status !== 200 || (await response.json()).status !== 'DELETED'
    ) throw new Error('expected deletion');
    const begin = calls.find((call) => call.url.includes('/rpc/begin_wedding_delete'));
    if (begin?.body?.p_verified_actor_user_id !== 'verified-owner') {
      throw new Error('actor override accepted');
    }
    const deletes = calls.filter((call) => call.url.includes('/object/wedding_media'));
    if (
      deletes.length !== 1 ||
      JSON.stringify(deletes[0].body?.prefixes) !==
        JSON.stringify([
          'weddings/wedding-a/cover.webp',
          'weddings/wedding-a/nested/second.webp',
        ])
    ) throw new Error('wrong cleanup target');
    const finalize = calls.findIndex((call) => call.url.includes('/rpc/finalize_wedding_delete'));
    if (
      !calls.slice(0, finalize).some((call) =>
        call.url.includes('/object/list/') &&
        call.body?.prefix === 'weddings/wedding-a/'
      )
    ) throw new Error('missing fresh root list');
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('returns retry-safe failure when Storage cleanup fails and never finalizes', async () => {
  const original = globalThis.fetch;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/object/list/')) {
      return new Response('failure', { status: 500 });
    }
    if (url.includes('/finalize')) throw new Error('must not finalize');
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    if (
      response.status !== 503 ||
      (await response.json()).error_code !== 'DELETE_RETRY_REQUIRED'
    ) throw new Error('expected safe retry');
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('empty prefix is idempotent', async () => {
  const calls: string[] = [];
  await cleanupWeddingStorage(
    'http://supabase.local',
    'key',
    'wedding-a',
    async (input) => {
      calls.push(String(input));
      return new Response(JSON.stringify([]));
    },
  );
  if (calls.length !== 1) throw new Error('empty prefix should list once');
});

Deno.test('paginates a directory and deletes bounded batches before a fresh empty list', async () => {
  let deleted = false;
  const deletes: string[][] = [];
  await cleanupWeddingStorage(
    'http://supabase.local',
    'key',
    'wedding-a',
    async (input, init) => {
      const url = String(input);
      const body = init?.body ? JSON.parse(String(init.body)) : {};
      if (url.includes('/object/list/')) {
        if (deleted) return new Response(JSON.stringify([]));
        if (body.offset === 0) {
          return new Response(
            JSON.stringify(
              Array.from(
                { length: 100 },
                (_, index) => ({
                  name: `cover-${index}.webp`,
                  id: String(index),
                }),
              ),
            ),
          );
        }
        if (body.offset === 100) {
          return new Response(
            JSON.stringify([{ name: 'cover-100.webp', id: '100' }]),
          );
        }
        throw new Error('unexpected offset');
      }
      deletes.push(body.prefixes);
      deleted = true;
      return new Response(JSON.stringify({}));
    },
  );
  if (
    deletes.length !== 2 || deletes[0].length !== 100 || deletes[1].length !== 1
  ) throw new Error('pagination or batching failed');
});

Deno.test('absent target returns generic terminal success without Storage or finalization', async () => {
  const original = globalThis.fetch;
  const calls: string[] = [];
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(JSON.stringify({ status: 'DELETED' }));
    }
    throw new Error('unexpected service call');
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'absent-wedding' }),
      }),
    );
    if (
      response.status !== 200 || (await response.json()).status !== 'DELETED' ||
      calls.length !== 2
    ) throw new Error('absent target leaked or performed cleanup');
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('oversized wedding-delete body is rejected before Auth or cleanup', async () => {
  const original = globalThis.fetch;
  let called = false;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = () => {
    called = true;
    return Promise.reject(new Error('must not call provider'));
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({
          wedding_id: 'wedding-a',
          padding: 'x'.repeat(DELETE_BODY_LIMIT_BYTES),
        }),
      }),
    );
    if (response.status !== 413 || called) {
      throw new Error('oversized delete request reached provider');
    }
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('Auth timeout is mapped to a bounded generic failure', async () => {
  const original = globalThis.fetch;
  Deno.env.set('SUPABASE_URL', 'http://provider.internal');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = () =>
    Promise.reject(
      new DOMException('auth timeout bearer-secret', 'AbortError'),
    );
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer bearer-secret' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    const text = await response.text();
    if (response.status !== 503 || !text.includes('TEMPORARY_ERROR')) {
      throw new Error('Auth timeout was not bounded');
    }
    if (/provider\.internal|bearer-secret|AbortError|stack/i.test(text)) {
      throw new Error('Auth detail leaked');
    }
    if (!response.headers.get('X-Request-ID')) {
      throw new Error('missing request correlation ID');
    }
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('Storage delete timeout leaves finalization untouched and returns retry required', async () => {
  const original = globalThis.fetch;
  let finalized = false;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/object/list/')) {
      return new Response(JSON.stringify([{ name: 'cover.webp', id: 'one' }]));
    }
    if (url.includes('/object/wedding_media')) {
      throw new DOMException('storage delete timeout', 'AbortError');
    }
    if (url.includes('/rpc/finalize_wedding_delete')) {
      finalized = true;
      return new Response(JSON.stringify({ status: 'DELETED' }));
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    if (
      response.status !== 503 ||
      (await response.json()).error_code !== 'DELETE_RETRY_REQUIRED' ||
      finalized
    ) {
      throw new Error('Storage timeout violated retry/finalization ordering');
    }
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('Storage list timeout leaves finalization untouched and returns retry required', async () => {
  const original = globalThis.fetch;
  let finalized = false;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/object/list/')) {
      throw new DOMException('storage list timeout', 'AbortError');
    }
    if (url.includes('/rpc/finalize_wedding_delete')) {
      finalized = true;
      return new Response(JSON.stringify({ status: 'DELETED' }));
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    if (
      response.status !== 503 ||
      (await response.json()).error_code !== 'DELETE_RETRY_REQUIRED' ||
      finalized
    ) {
      throw new Error(
        'Storage list timeout violated retry/finalization ordering',
      );
    }
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('finalize timeout after an empty prefix remains retry safe', async () => {
  const original = globalThis.fetch;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/object/list/')) return new Response(JSON.stringify([]));
    if (url.includes('/rpc/finalize_wedding_delete')) {
      throw new DOMException('finalize timeout', 'AbortError');
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    if (
      response.status !== 503 ||
      (await response.json()).error_code !== 'DELETE_RETRY_REQUIRED'
    ) {
      throw new Error('finalize timeout was not retry safe');
    }
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test('finalize bridge failure logs a bounded stage without provider details', async () => {
  const original = globalThis.fetch;
  const originalLog = console.log;
  const logs: string[] = [];
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  console.log = (value: unknown) => logs.push(String(value));
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) {
      return new Response(JSON.stringify({ id: 'verified-owner' }));
    }
    if (url.includes('/rpc/begin_wedding_delete')) {
      return new Response(
        JSON.stringify({ status: 'DELETING', wedding_id: 'wedding-a' }),
      );
    }
    if (url.includes('/object/list/')) return new Response(JSON.stringify([]));
    if (url.includes('/rpc/finalize_wedding_delete')) {
      return new Response('provider-internal sqlstate token-value', { status: 500 });
    }
    throw new Error(`unexpected ${url}`);
  };
  try {
    const response = await beginWeddingDelete(
      new Request('http://local', {
        method: 'POST',
        headers: { authorization: 'Bearer valid' },
        body: JSON.stringify({ wedding_id: 'wedding-a' }),
      }),
    );
    const responseText = await response.text();
    const event = logs.map((line) => JSON.parse(line)).find((entry) =>
      entry.event === 'edge_delete_stage_failed'
    );
    if (
      response.status !== 503 ||
      !responseText.includes('DELETE_RETRY_REQUIRED') ||
      /provider-internal|sqlstate|token-value/i.test(responseText) ||
      event?.stage !== 'finalize_bridge' ||
      event?.status_category !== '5xx' ||
      typeof event?.correlation_id !== 'string' ||
      /provider-internal|sqlstate|token-value/i.test(JSON.stringify(event))
    ) {
      throw new Error('finalize failure diagnostics leaked or lost the bounded stage');
    }
  } finally {
    globalThis.fetch = original;
    console.log = originalLog;
  }
});
