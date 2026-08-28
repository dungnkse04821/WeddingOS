import { isValidRawToken, networkSignal, parseAllowedOrigins, publicError, securityHeaders, sha256Hex } from '../invitation-resolve/index.ts';
import { BoundedBodyError, boundedInteger, createCorrelationId, fetchWithDeadline, readBoundedJson, readBoundedResponseJson } from '../_shared/edge_safety.ts';
import { logEdgeCompletion } from '../_shared/operational_log.ts';

type SubmitResult = {
  ok: boolean;
  http_status?: number;
  error_code?: string;
  retry_after_seconds?: number;
  can_submit_rsvp?: boolean;
  rsvp?: unknown;
  vietqr?: unknown;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const RSVP_BODY_LIMIT_BYTES = 32 * 1024;
export const RSVP_RESPONSE_LIMIT = 20;
const DATABASE_TIMEOUT_MS = 8_000;
const AUTHORITY_RESPONSE_LIMIT_BYTES = 1024 * 1024;

function validOptionalFields(value: unknown): value is Record<string, unknown> {
  if (value === undefined) return true;
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const fields = value as Record<string, unknown>;
  if (
    Object.keys(fields).some((key) =>
      !['guest_message', 'dietary_info', 'note', 'companion_names'].includes(
        key,
      )
    )
  ) return false;
  if (
    typeof fields.guest_message === 'string' &&
    fields.guest_message.length > 1000
  ) return false;
  if (
    typeof fields.dietary_info === 'string' && fields.dietary_info.length > 500
  ) return false;
  if (typeof fields.note === 'string' && fields.note.length > 1000) {
    return false;
  }
  if ('companion_names' in fields && fields.companion_names !== null) {
    if (
      !Array.isArray(fields.companion_names) ||
      fields.companion_names.length > 20
    ) return false;
    if (
      !fields.companion_names.every((name) => typeof name === 'string' && name.length <= 100)
    ) return false;
  }
  return ['guest_message', 'dietary_info', 'note'].every((key) => !(key in fields) || fields[key] === null || typeof fields[key] === 'string');
}

function validResponses(
  value: unknown,
): value is Array<Record<string, unknown>> {
  if (
    !Array.isArray(value) || value.length === 0 ||
    value.length > RSVP_RESPONSE_LIMIT
  ) return false;
  const seen = new Set<string>();
  return value.every((response) => {
    if (!response || typeof response !== 'object') return false;
    const item = response as Record<string, unknown>;
    const eventId = item.event_id;
    const status = item.response_status;
    const count = item.attending_count;
    if (
      typeof eventId !== 'string' || !uuidPattern.test(eventId) ||
      seen.has(eventId)
    ) return false;
    seen.add(eventId);
    return (status === 'ATTENDING' && Number.isInteger(count) &&
      (count as number) >= 1) ||
      (status === 'NOT_ATTENDING' && count === 0);
  });
}

export async function submitRsvp(request: Request): Promise<Response> {
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
    const response = await submitRsvpCore(request, allowedOrigins, origin, headers);
    logEdgeCompletion('invitation_rsvp', requestId, startedAt, response.status);
    return response;
  } catch (_) {
    const response = publicError(503, 'TEMPORARY_UNAVAILABLE', headers);
    logEdgeCompletion('invitation_rsvp', requestId, startedAt, response.status, console.log, true);
    return response;
  }
}

async function submitRsvpCore(
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

  let body: Record<string, unknown>;
  try {
    const parsed = await readBoundedJson(request, RSVP_BODY_LIMIT_BYTES);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error('invalid');
    }
    body = parsed as Record<string, unknown>;
  } catch (error) {
    if (error instanceof BoundedBodyError && error.kind === 'too_large') {
      return publicError(413, 'INVALID_RESPONSE', headers);
    }
    return publicError(400, 'INVALID_RESPONSE', headers);
  }
  if (!isValidRawToken(body.raw_token)) {
    return publicError(404, 'INVITATION_UNAVAILABLE', headers);
  }
  if (
    !validResponses(body.responses) ||
    !validOptionalFields(body.optional_fields)
  ) {
    return publicError(400, 'INVALID_RESPONSE', headers);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return publicError(503, 'TEMPORARY_UNAVAILABLE', headers);
  }

  try {
    const networkHash = await sha256Hex(`D-RSV-001:${networkSignal(request)}`);
    const rpcResponse = await fetchWithDeadline(
      fetch,
      `${supabaseUrl}/rest/v1/rpc/submit_public_rsvp`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept-Profile': 'edge_api',
          'Content-Profile': 'edge_api',
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          p_raw_token: body.raw_token,
          p_responses: body.responses,
          p_optional_fields: body.optional_fields ?? {},
          p_limiter_key: `D-RSV-001:ip:${networkHash}`,
          p_rate_limit_threshold: boundedInteger(
            Deno.env.get('CLASS_D_RSVP_RATE_LIMIT'),
            10,
            1,
            100,
          ),
        }),
      },
      DATABASE_TIMEOUT_MS,
    );
    if (!rpcResponse.ok) {
      return publicError(503, 'TEMPORARY_UNAVAILABLE', headers);
    }
    const result = await readBoundedResponseJson(
      rpcResponse,
      AUTHORITY_RESPONSE_LIMIT_BYTES,
    ) as SubmitResult;
    if (!result.ok) {
      const status = result.http_status ?? 503;
      const code = result.error_code ?? 'TEMPORARY_UNAVAILABLE';
      if (status === 429 && result.retry_after_seconds) {
        headers.set('Retry-After', String(result.retry_after_seconds));
      }
      return publicError(status, code, headers);
    }
    return new Response(
      JSON.stringify({
        ok: true,
        can_submit_rsvp: result.can_submit_rsvp,
        rsvp: result.rsvp,
        vietqr: result.vietqr,
      }),
      {
        status: 200,
        headers,
      },
    );
  } catch (_) {
    return publicError(503, 'TEMPORARY_UNAVAILABLE', headers);
  }
}

if (import.meta.main) Deno.serve(submitRsvp);
