import { RSVP_BODY_LIMIT_BYTES, RSVP_RESPONSE_LIMIT, submitRsvp } from './index.ts';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

Deno.test('rejects malformed RSVP bodies without database access', async () => {
  const response = await submitRsvp(
    new Request('http://localhost/v1/invitation/rsvp', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        origin: 'http://localhost:5173',
      },
      body: JSON.stringify({
        raw_token: token,
        responses: [{
          event_id: 'not-a-uuid',
          response_status: 'ATTENDING',
          attending_count: 1,
        }],
      }),
    }),
  );
  const body = await response.json();
  if (response.status !== 400 || body.error_code !== 'INVALID_RESPONSE') {
    throw new Error('Expected safe invalid RSVP response.');
  }
  if (response.headers.get('Cache-Control') !== 'no-store') {
    throw new Error('RSVP must not be cached.');
  }
});

Deno.test('does not use raw token as a URL or limiter value', async () => {
  const response = await submitRsvp(
    new Request('http://localhost/v1/invitation/rsvp', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        origin: 'http://localhost:5173',
      },
      body: JSON.stringify({
        raw_token: token,
        responses: [{
          event_id: '11111111-1111-4111-8111-111111111111',
          response_status: 'ATTENDING',
          attending_count: 1,
        }],
      }),
    }),
  );
  const body = await response.json();
  if (response.status !== 503 || body.error_code !== 'TEMPORARY_UNAVAILABLE') {
    throw new Error('Expected env-safe temporary error.');
  }
});

function responses(count: number): Array<Record<string, unknown>> {
  return Array.from({ length: count }, (_, index) => ({
    event_id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, '0')}`,
    response_status: 'ATTENDING',
    attending_count: 1,
  }));
}

Deno.test('RSVP accepts the response-count limit and rejects one above it', async () => {
  Deno.env.delete('SUPABASE_URL');
  Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
  const atLimit = await submitRsvp(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({
        raw_token: token,
        responses: responses(RSVP_RESPONSE_LIMIT),
      }),
    }),
  );
  if (atLimit.status !== 503) {
    throw new Error('at-limit response collection did not pass validation');
  }

  const aboveLimit = await submitRsvp(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({
        raw_token: token,
        responses: responses(RSVP_RESPONSE_LIMIT + 1),
      }),
    }),
  );
  if (
    aboveLimit.status !== 400 ||
    (await aboveLimit.json()).error_code !== 'INVALID_RESPONSE'
  ) {
    throw new Error('above-limit response collection was not rejected');
  }
});

Deno.test('oversized RSVP body is rejected before provider access', async () => {
  const response = await submitRsvp(
    new Request('http://local', {
      method: 'POST',
      body: JSON.stringify({
        raw_token: token,
        responses: responses(1),
        padding: 'x'.repeat(RSVP_BODY_LIMIT_BYTES),
      }),
    }),
  );
  if (
    response.status !== 413 ||
    (await response.json()).error_code !== 'INVALID_RESPONSE'
  ) {
    throw new Error('oversized RSVP body was not bounded');
  }
});

Deno.test('RSVP provider exception has a bounded public envelope', async () => {
  const original = globalThis.fetch;
  Deno.env.set('SUPABASE_URL', 'http://provider.internal');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'server-only-test-value');
  globalThis.fetch = () =>
    Promise.reject(
      new DOMException('provider timeout secret-token', 'AbortError'),
    );
  try {
    const response = await submitRsvp(
      new Request('http://local', {
        method: 'POST',
        body: JSON.stringify({ raw_token: token, responses: responses(1) }),
      }),
    );
    const text = await response.text();
    if (response.status !== 503 || !text.includes('TEMPORARY_UNAVAILABLE')) {
      throw new Error('RSVP timeout was not bounded');
    }
    if (/provider\.internal|secret-token|AbortError|stack/i.test(text)) {
      throw new Error('RSVP provider detail leaked');
    }
  } finally {
    globalThis.fetch = original;
    Deno.env.delete('SUPABASE_URL');
    Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
  }
});
