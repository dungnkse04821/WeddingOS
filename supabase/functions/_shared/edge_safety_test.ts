import { BoundedBodyError, boundedInteger, createCorrelationId, fetchWithDeadline, readBoundedJson, readBoundedResponseJson } from './edge_safety.ts';

Deno.test('bounded request JSON accepts a normal body', async () => {
  const parsed = await readBoundedJson(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ value: 'safe' }),
    }),
    64,
  ) as Record<string, unknown>;
  if (parsed.value !== 'safe') throw new Error('normal JSON was not parsed');
});

Deno.test('bounded request JSON rejects an oversized stream without Content-Length trust', async () => {
  try {
    const request = new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({ value: 'x'.repeat(100) }),
    });
    if (request.headers.has('content-length')) {
      throw new Error('test requires an absent Content-Length header');
    }
    await readBoundedJson(request, 32);
    throw new Error('oversized body was accepted');
  } catch (error) {
    if (!(error instanceof BoundedBodyError) || error.kind !== 'too_large') {
      throw error;
    }
  }
});

Deno.test('bounded provider JSON rejects oversized responses', async () => {
  try {
    await readBoundedResponseJson(
      new Response(JSON.stringify({ value: 'x'.repeat(100) })),
      32,
    );
    throw new Error('oversized provider response was accepted');
  } catch (error) {
    if (!(error instanceof BoundedBodyError) || error.kind !== 'too_large') {
      throw error;
    }
  }
});

Deno.test('provider deadline aborts deterministically and clears its timer', async () => {
  let callback: (() => void) | undefined;
  let cleared = false;
  const promise = fetchWithDeadline(
    (_input, init) =>
      new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new DOMException('timed out', 'AbortError')));
      }),
    'http://provider.local',
    {},
    8000,
    (scheduled) => {
      callback = scheduled;
      return 1 as unknown as ReturnType<typeof setTimeout>;
    },
    () => {
      cleared = true;
    },
  );
  callback?.();
  try {
    await promise;
    throw new Error('deadline did not abort');
  } catch (error) {
    if (!(error instanceof DOMException) || error.name !== 'AbortError') {
      throw error;
    }
  }
  if (!cleared) throw new Error('deadline timer was not cleared');
});

Deno.test('numeric configuration uses only bounded integers', () => {
  if (boundedInteger('60', 30, 1, 300) !== 60) {
    throw new Error('valid value rejected');
  }
  for (const value of ['0', '301', '-1', '1.5', 'Infinity', 'bad']) {
    if (boundedInteger(value, 30, 1, 300) !== 30) {
      throw new Error(`unsafe value accepted: ${value}`);
    }
  }
});

Deno.test('correlation IDs are server-generated UUIDs', () => {
  const first = createCorrelationId();
  const second = createCorrelationId();
  if (first === second || !/^[0-9a-f-]{36}$/i.test(first)) {
    throw new Error('invalid correlation IDs');
  }
});
