import { BoundedBodyError, boundedInteger, createCorrelationId, fetchWithDeadline, readBoundedJson, readBoundedResponseJson } from '../_shared/edge_safety.ts';
import { logEdgeCompletion } from '../_shared/operational_log.ts';

type ResolveRpcResult = {
  ok: boolean;
  http_status?: number;
  error_code?: string;
  retry_after_seconds?: number;
  invitation?: unknown;
  cover_photo_key?: string | null;
};

const DEFAULT_ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://127.0.0.1:5173',
];

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
export const RESOLVE_BODY_LIMIT_BYTES = 2 * 1024;
export const DATABASE_TIMEOUT_MS = 8_000;
export const SIGNED_URL_TIMEOUT_MS = 5_000;
const AUTHORITY_RESPONSE_LIMIT_BYTES = 1024 * 1024;
const SIGNED_URL_RESPONSE_LIMIT_BYTES = 64 * 1024;

export function parseAllowedOrigins(value: string | undefined): Set<string> {
  const configured = value
    ?.split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
  return new Set(
    configured && configured.length > 0 ? configured : DEFAULT_ALLOWED_ORIGINS,
  );
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

export function securityHeaders(
  origin: string | null,
  allowedOrigins: Set<string>,
): Headers {
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

export function publicError(
  status: number,
  code: string,
  headers: Headers,
): Response {
  return new Response(JSON.stringify({ ok: false, error_code: code }), {
    status,
    headers,
  });
}

export function networkSignal(request: Request): string {
  // Only Cloudflare's provider header is eligible for a network partition.
  // Direct local/Supabase requests can supply X-Forwarded-For and X-Real-IP.
  return request.headers.get('cf-connecting-ip')?.trim() || 'unverified-network';
}

export async function classDLimiterKey(
  route: 'D-INV-001' | 'D-RSV-001',
  rawToken: string,
  request: Request,
): Promise<string> {
  const [networkHash, tokenHash] = await Promise.all([
    sha256Hex(`${route}:network:${networkSignal(request)}`),
    sha256Hex(`${route}:token:${rawToken}`),
  ]);
  // The persisted key is route-scoped and contains only truncated SHA-256 output.
  return `${route}:n:${networkHash.slice(0, 32)}:t:${tokenHash.slice(0, 32)}`;
}

export async function resolveInvitation(request: Request): Promise<Response> {
  const startedAt = performance.now();
  const requestId = createCorrelationId();
  let headers = securityHeaders(null, new Set());
  headers.set('X-Request-ID', requestId);
  try {
    const allowedOrigins = parseAllowedOrigins(
      Deno.env.get('GUEST_WEB_ALLOWED_ORIGINS'),
    );
    const origin = request.headers.get('origin');
    headers = securityHeaders(origin, allowedOrigins);
    headers.set('X-Request-ID', requestId);
    const response = await resolveInvitationCore(
      request,
      allowedOrigins,
      origin,
      headers,
    );
    logEdgeCompletion('invitation_resolve', requestId, startedAt, response.status);
    return response;
  } catch (_) {
    const response = publicError(503, 'TEMPORARY_ERROR', headers);
    logEdgeCompletion('invitation_resolve', requestId, startedAt, response.status, console.log, true);
    return response;
  }
}

async function resolveInvitationCore(
  request: Request,
  allowedOrigins: Set<string>,
  origin: string | null,
  headers: Headers,
): Promise<Response> {
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
    const body = await readBoundedJson(
      request,
      RESOLVE_BODY_LIMIT_BYTES,
    ) as Record<string, unknown>;
    rawToken = body?.raw_token;
  } catch (error) {
    if (error instanceof BoundedBodyError && error.kind === 'too_large') {
      return publicError(413, 'INVITATION_UNAVAILABLE', headers);
    }
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
    const limiterKey = await classDLimiterKey('D-INV-001', rawToken, request);
    const rpcResponse = await fetchWithDeadline(
      fetch,
      `${supabaseUrl}/rest/v1/rpc/resolve_public_invitation`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept-Profile': 'edge_api',
          'Content-Profile': 'edge_api',
          'apikey': serviceRoleKey,
          'Authorization': `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_raw_token: rawToken,
          p_limiter_key: limiterKey,
          p_rate_limit_threshold: boundedInteger(
            Deno.env.get('CLASS_D_RESOLVE_RATE_LIMIT'),
            30,
            1,
            300,
          ),
        }),
      },
      DATABASE_TIMEOUT_MS,
    );

    if (!rpcResponse.ok) {
      return publicError(503, 'TEMPORARY_ERROR', headers);
    }

    const result = await readBoundedResponseJson(
      rpcResponse,
      AUTHORITY_RESPONSE_LIMIT_BYTES,
    ) as ResolveRpcResult;
    if (!result.ok) {
      const status = result.http_status ?? 404;
      if (status === 429 && result.retry_after_seconds) {
        headers.set('Retry-After', String(result.retry_after_seconds));
      }
      return publicError(
        status,
        result.error_code ?? 'INVITATION_UNAVAILABLE',
        headers,
      );
    }

    let coverPhotoSignedUrl: string | null = null;
    if (
      typeof result.cover_photo_key === 'string' &&
      /^weddings\/[0-9a-f-]{36}\/cover\.webp$/i.test(result.cover_photo_key)
    ) {
      try {
        const signed = await fetchWithDeadline(
          fetch,
          `${supabaseUrl}/storage/v1/object/sign/wedding_media/${result.cover_photo_key}`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              apikey: serviceRoleKey,
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              expiresIn: boundedInteger(
                Deno.env.get('COVER_PHOTO_SIGNED_URL_TTL_SECONDS'),
                1800,
                60,
                3600,
              ),
            }),
          },
          SIGNED_URL_TIMEOUT_MS,
        );
        if (signed.ok) {
          const body = await readBoundedResponseJson(
            signed,
            SIGNED_URL_RESPONSE_LIMIT_BYTES,
          ) as { signedURL?: string };
          if (body.signedURL) {
            coverPhotoSignedUrl = `${supabaseUrl}/storage/v1${body.signedURL}`;
          }
        }
      } catch (_) { /* Optional media must not break a valid invitation. */ }
    }
    const invitation = result.invitation as Record<string, unknown>;
    return new Response(
      JSON.stringify({
        ok: true,
        invitation: {
          ...invitation,
          cover_photo_signed_url: coverPhotoSignedUrl,
        },
      }),
      {
        status: 200,
        headers,
      },
    );
  } catch (_) {
    return publicError(503, 'TEMPORARY_ERROR', headers);
  }
}

if (import.meta.main) {
  Deno.serve(resolveInvitation);
}
