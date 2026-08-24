import { submitRsvp } from './index.ts';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

Deno.test('rejects malformed RSVP bodies without database access', async () => {
  const response = await submitRsvp(new Request('http://localhost/v1/invitation/rsvp', {
    method: 'POST', headers: { 'content-type': 'application/json', origin: 'http://localhost:5173' },
    body: JSON.stringify({ raw_token: token, responses: [{ event_id: 'not-a-uuid', response_status: 'ATTENDING', attending_count: 1 }] }),
  }));
  const body = await response.json();
  if (response.status !== 400 || body.error_code !== 'INVALID_RESPONSE') throw new Error('Expected safe invalid RSVP response.');
  if (response.headers.get('Cache-Control') !== 'no-store') throw new Error('RSVP must not be cached.');
});

Deno.test('does not use raw token as a URL or limiter value', async () => {
  const response = await submitRsvp(new Request('http://localhost/v1/invitation/rsvp', {
    method: 'POST', headers: { 'content-type': 'application/json', origin: 'http://localhost:5173' },
    body: JSON.stringify({ raw_token: token, responses: [{ event_id: '11111111-1111-4111-8111-111111111111', response_status: 'ATTENDING', attending_count: 1 }] }),
  }));
  const body = await response.json();
  if (response.status !== 503 || body.error_code !== 'TEMPORARY_UNAVAILABLE') throw new Error('Expected env-safe temporary error.');
});
