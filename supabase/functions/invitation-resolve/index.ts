type ResolveRpcResult = {
  ok: boolean;
  http_status?: number;
  error_code?: string;
  retry_after_seconds?: number;
  invitation?: unknown;
};

const DEFAULT_ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://127.0.0.1:5173',
];

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export function parseAllowedOrigins(value: string | undefined): Set<string> {
  const configured = value
    ?.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
  return new Set(configured && configured.length > 0 ? configured : DEFAULT_ALLOWED_ORIGINS);
}

export function isValidRawToken(value: unknown): value is string {
  return typeof value === 'string' && TOKEN_PATTERN.test(value);
}

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export function securityHeaders(origin: string | null, allowedOrigins: Set<string>): Headers {
  const headers = new Headers({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'Vary': 'Origin',
  });

  if (origin && allowedOrigins.has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
    headers.set('Access-Control-Allow-Headers', 'content-type');
    headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    headers.set('Access-Control-Max-Age', '600');
  }

  return headers;
}

export function publicError(status: number, code: string, headers: Headers): Response {
  return new Response(JSON.stringify({ ok: false, error_code: code }), {
    status,
    headers,
  });
}

export function networkSignal(request: Request): string {
  const forwardedFor = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return request.headers.get('cf-connecting-ip')?.trim() ||
    forwardedFor ||
    'unknown-network';
}

export async function resolveInvitation(request: Request): Promise<Response> {
  const allowedOrigins = parseAllowedOrigins(Deno.env.get('GUEST_WEB_ALLOWED_ORIGINS'));
  const origin = request.headers.get('origin');
  const headers = securityHeaders(origin, allowedOrigins);

  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }

  if (origin && !allowedOrigins.has(origin)) {
    return publicError(403, 'TEMPORARY_ERROR', headers);
  }

  if (request.method !== 'POST') {
    return publicError(405, 'TEMPORARY_ERROR', headers);
  }

  let rawToken: unknown;
  try {
    const body = await request.json();
    rawToken = body?.raw_token;
  } catch (_) {
    return publicError(404, 'INVITATION_UNAVAILABLE', headers);
  }

  if (!isValidRawToken(rawToken)) {
    return publicError(404, 'INVITATION_UNAVAILABLE', headers);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return publicError(503, 'TEMPORARY_ERROR', headers);
  }

  try {
    const networkHash = await sha256Hex(`D-INV-001:${networkSignal(request)}`);
    const rpcResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/resolve_public_invitation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        p_raw_token: rawToken,
        p_limiter_key: `D-INV-001:ip:${networkHash}`,
        p_rate_limit_threshold: Number(Deno.env.get('CLASS_D_RESOLVE_RATE_LIMIT') ?? '30'),
      }),
    });

    if (!rpcResponse.ok) {
      return publicError(503, 'TEMPORARY_ERROR', headers);
    }

    const result = await rpcResponse.json() as ResolveRpcResult;
    if (!result.ok) {
      const status = result.http_status ?? 404;
      if (status === 429 && result.retry_after_seconds) {
        headers.set('Retry-After', String(result.retry_after_seconds));
      }
      return publicError(status, result.error_code ?? 'INVITATION_UNAVAILABLE', headers);
    }

    return new Response(JSON.stringify({
      ok: true,
      invitation: result.invitation,
    }), {
      status: 200,
      headers,
    });
  } catch (_) {
    return publicError(503, 'TEMPORARY_ERROR', headers);
  }
}

if (import.meta.main) {
  Deno.serve(resolveInvitation);
}
