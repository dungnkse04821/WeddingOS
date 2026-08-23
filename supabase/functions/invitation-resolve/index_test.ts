import {
  isValidRawToken,
  parseAllowedOrigins,
  resolveInvitation,
  securityHeaders,
  sha256Hex,
} from './index.ts';

Deno.test('validates DEC-B-002 structural token format', () => {
  if (!isValidRawToken('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345')) {
    throw new Error('Expected 43-char base64url token to be valid.');
  }
  if (isValidRawToken('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk01234=')) {
    throw new Error('Expected padded token to be invalid.');
  }
  if (isValidRawToken('not-a-token')) {
    throw new Error('Expected malformed token to be invalid.');
  }
});

Deno.test('security headers use no-store and narrow CORS origin', () => {
  const origins = parseAllowedOrigins('https://guest.example.com');
  const headers = securityHeaders('https://guest.example.com', origins);

  if (headers.get('Cache-Control') !== 'no-store') {
    throw new Error('Personalized resolve response must be no-store.');
  }
  if (headers.get('Referrer-Policy') !== 'no-referrer') {
    throw new Error('Guest Web response must use no-referrer policy.');
  }
  if (headers.get('Access-Control-Allow-Origin') !== 'https://guest.example.com') {
    throw new Error('Expected configured origin to be allowed.');
  }

  const denied = securityHeaders('https://evil.example.com', origins);
  if (denied.has('Access-Control-Allow-Origin')) {
    throw new Error('Unexpected CORS allow header for unconfigured origin.');
  }
});

Deno.test('malformed token returns generic unavailable without Supabase env', async () => {
  const response = await resolveInvitation(new Request('http://localhost/v1/invitation/resolve', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'origin': 'http://localhost:5173',
    },
    body: JSON.stringify({ raw_token: 'bad-token' }),
  }));

  const body = await response.json();
  if (response.status !== 404 || body.error_code !== 'INVITATION_UNAVAILABLE') {
    throw new Error('Malformed tokens must fail as generic unavailable.');
  }
  if (response.headers.get('Cache-Control') !== 'no-store') {
    throw new Error('Error responses must also be no-store.');
  }
});

Deno.test('limiter digest does not contain raw network signal', async () => {
  const digest = await sha256Hex('D-INV-001:203.0.113.10');
  if (!/^[a-f0-9]{64}$/.test(digest)) {
    throw new Error('Expected SHA-256 hex digest.');
  }
  if (digest.includes('203.0.113.10')) {
    throw new Error('Digest must not contain raw network signal.');
  }
});
