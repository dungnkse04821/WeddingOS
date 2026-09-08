import { classDLimiterKey, classDProvenance, isValidRawToken, networkSignal, parseAllowedOrigins, RESOLVE_BODY_LIMIT_BYTES, resolveInvitation, securityHeaders, sha256Hex } from './index.ts';

const validToken = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

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
  if (
    headers.get('Access-Control-Allow-Origin') !== 'https://guest.example.com'
  ) {
    throw new Error('Expected configured origin to be allowed.');
  }

  const denied = securityHeaders('https://evil.example.com', origins);
  if (denied.has('Access-Control-Allow-Origin')) {
    throw new Error('Unexpected CORS allow header for unconfigured origin.');
  }
});

Deno.test('malformed token returns generic unavailable without Supabase env', async () => {
  const response = await resolveInvitation(
    new Request('http://localhost/v1/invitation/resolve', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'origin': 'http://localhost:5173',
      },
      body: JSON.stringify({ raw_token: 'bad-token' }),
    }),
  );

  const body = await response.json();
  if (response.status !== 404 || body.error_code !== 'INVITATION_UNAVAILABLE') {
    throw new Error('Malformed tokens must fail as generic unavailable.');
  }
  if (response.headers.get('Cache-Control') !== 'no-store') {
    throw new Error('Error responses must also be no-store.');
  }
});

Deno.test('limiter digest does not contain raw network signal', async () => {
  const rawSignal = 'D-INV-001:provider-network-signal';
  const digest = await sha256Hex(rawSignal);
  if (!/^[a-f0-9]{64}$/.test(digest)) {
    throw new Error('Expected SHA-256 hex digest.');
  }
  if (digest.includes(rawSignal)) {
    throw new Error('Digest must not contain raw network signal.');
  }
});

Deno.test('Class-D limiter keys require gateway proof for trusted Cloudflare provenance', async () => {
  const token = validToken;
  const cloudflareRequest = new Request('http://local', {
    headers: {
      'cf-connecting-ip': '198.51.100.17',
      'x-forwarded-for': '203.0.113.18, 10.0.0.1',
      'x-real-ip': '192.0.2.9',
      forwarded: 'for=203.0.113.19',
      'x-weddingos-gateway-proof': 'trusted-proof',
    },
  });
  const cloudflareProvenance = classDProvenance(cloudflareRequest, 'trusted-proof');
  if (cloudflareProvenance.provenance !== 'cloudflare' || !cloudflareProvenance.trustedGateway || !cloudflareProvenance.trustedCfIpPresent || !cloudflareProvenance.gatewayProofEnvPresent || !cloudflareProvenance.gatewayProofHeaderPresent || !cloudflareProvenance.gatewayProofMatch || cloudflareProvenance.network !== '198.51.100.17') {
    throw new Error('Valid gateway proof must be required before trusting CF-Connecting-IP.');
  }
  const directRequest = new Request('http://local', {
    headers: {
      'cf-connecting-ip': '203.0.113.200',
      'x-forwarded-for': '203.0.113.18',
      'x-real-ip': '192.0.2.9',
      forwarded: 'for=203.0.113.19',
      'x-weddingos-gateway-proof': 'forged-proof',
    },
  });
  const directProvenance = classDProvenance(directRequest, 'trusted-proof');
  if (directProvenance.provenance !== 'unverified' || directProvenance.trustedGateway || directProvenance.trustedCfIpPresent || !directProvenance.gatewayProofEnvPresent || !directProvenance.gatewayProofHeaderPresent || directProvenance.gatewayProofMatch || directProvenance.network !== 'unverified-network') {
    throw new Error('Forged forwarding headers or gateway proof must not become trusted.');
  }
  if (networkSignal(directRequest) !== 'unverified-network') {
    throw new Error('Direct calls must use the unverified network partition.');
  }
  const key = await classDLimiterKey('D-INV-001', token, cloudflareRequest, cloudflareProvenance);
  const sameNetworkOtherToken = await classDLimiterKey(
    'D-INV-001',
    'BCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk0123456',
    cloudflareRequest,
    cloudflareProvenance,
  );
  const rsvpKey = await classDLimiterKey('D-RSV-001', token, cloudflareRequest, cloudflareProvenance);
  if (!/^D-INV-001:n:[a-f0-9]{32}:t:[a-f0-9]{32}$/.test(key)) {
    throw new Error('Unexpected bounded Class-D limiter key format.');
  }
  if (key.includes(token) || key.includes('198.51.100.17') || key.includes('trusted-proof')) {
    throw new Error('Limiter key leaked token or network source.');
  }
  if (key === sameNetworkOtherToken || key === rsvpKey) {
    throw new Error('Token and route dimensions must both partition limiter state.');
  }
});

Deno.test('normal resolve body passes parsing and oversized body is rejected before provider access', async () => {
  const normal = await resolveInvitation(
    new Request('http://localhost/v1/invitation/resolve', {
      method: 'POST',
      body: JSON.stringify({ raw_token: validToken }),
    }),
  );
  if (normal.status !== 503) {
    throw new Error(
      'normal body did not pass parsing to environment validation',
    );
  }

  const oversized = await resolveInvitation(
    new Request('http://localhost/v1/invitation/resolve', {
      method: 'POST',
      body: JSON.stringify({
        raw_token: validToken,
        padding: 'x'.repeat(RESOLVE_BODY_LIMIT_BYTES),
      }),
    }),
  );
  const body = await oversized.json();
  if (
    oversized.status !== 413 || body.error_code !== 'INVITATION_UNAVAILABLE'
  ) throw new Error('oversized resolve body was not bounded');
});

Deno.test('database provider exception is returned as a bounded resolve error', async () => {
  const original = globalThis.fetch;
  Deno.env.set('SUPABASE_URL', 'http://provider.internal');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'server-only-test-value');
  globalThis.fetch = () => Promise.reject(new Error('provider.internal SQLSTATE secret-token'));
  try {
    const response = await resolveInvitation(
      new Request('http://local', {
        method: 'POST',
        body: JSON.stringify({ raw_token: validToken }),
      }),
    );
    const text = await response.text();
    if (response.status !== 503 || !text.includes('TEMPORARY_ERROR')) {
      throw new Error('provider exception was not bounded');
    }
    if (/provider\.internal|SQLSTATE|secret-token|stack/i.test(text)) {
      throw new Error('provider detail leaked');
    }
    if (!response.headers.get('X-Request-ID')) {
      throw new Error('missing correlation ID');
    }
  } finally {
    globalThis.fetch = original;
    Deno.env.delete('SUPABASE_URL');
    Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
  }
});

Deno.test('signed URL TTL falls back to 1800 when configuration is unsafe', async () => {
  const original = globalThis.fetch;
  let expiresIn: unknown;
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'server-only-test-value');
  Deno.env.set('COVER_PHOTO_SIGNED_URL_TTL_SECONDS', '999999');
  globalThis.fetch = async (input, init) => {
    const url = String(input);
    if (url.includes('/rpc/resolve_public_invitation')) {
      return new Response(
        JSON.stringify({
          ok: true,
          invitation: {},
          cover_photo_key: 'weddings/11111111-1111-4111-8111-111111111111/cover.webp',
        }),
      );
    }
    if (url.includes('/object/sign/')) {
      expiresIn = JSON.parse(String(init?.body)).expiresIn;
      return new Response(JSON.stringify({ signedURL: '/signed/path' }));
    }
    throw new Error('unexpected provider call');
  };
  try {
    const response = await resolveInvitation(
      new Request('http://local', {
        method: 'POST',
        body: JSON.stringify({ raw_token: validToken }),
      }),
    );
    if (response.status !== 200 || expiresIn !== 1800) {
      throw new Error('unsafe TTL did not fall back safely');
    }
  } finally {
    globalThis.fetch = original;
    Deno.env.delete('SUPABASE_URL');
    Deno.env.delete('SUPABASE_SERVICE_ROLE_KEY');
    Deno.env.delete('COVER_PHOTO_SIGNED_URL_TTL_SECONDS');
  }
});
