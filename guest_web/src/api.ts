import type { ResolveResponse, RsvpSubmitResponse } from './types';

const defaultEndpoint = '/v1/invitation/resolve';
export const RESOLVE_TIMEOUT_MS = 15_000;
export const RSVP_TIMEOUT_MS = 12_000;

type Fetcher = typeof fetch;
type RequestOptions = {
  fetcher?: Fetcher;
  schedule?: typeof setTimeout;
  cancel?: typeof clearTimeout;
};

async function fetchWithTimeout(
  endpoint: string,
  init: Parameters<Fetcher>[1],
  timeoutMs: number,
  options: RequestOptions,
): Promise<Response> {
  const controller = new AbortController();
  const schedule = options.schedule ?? setTimeout;
  const cancel = options.cancel ?? clearTimeout;
  const timer = schedule(() => controller.abort(), timeoutMs);
  try {
    return await (options.fetcher ?? fetch)(endpoint, { ...init, signal: controller.signal });
  } finally {
    cancel(timer);
  }
}

export async function resolveInvitation(rawToken: string, options: RequestOptions = {}): Promise<ResolveResponse> {
  const endpoint = import.meta.env.VITE_INVITATION_RESOLVE_URL ?? defaultEndpoint;
  let response: Response;
  try {
    response = await fetchWithTimeout(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      cache: 'no-store',
      body: JSON.stringify({ raw_token: rawToken }),
    }, RESOLVE_TIMEOUT_MS, options);
  } catch {
    return { ok: false, error_code: 'TEMPORARY_ERROR' };
  }

  const body = await response.json().catch(() => null);
  if (response.status === 429) {
    return { ok: false, error_code: 'RATE_LIMITED' };
  }
  if (response.status >= 500) {
    return { ok: false, error_code: 'TEMPORARY_ERROR' };
  }
  if (!response.ok || body?.ok !== true) {
    return { ok: false, error_code: 'INVITATION_UNAVAILABLE' };
  }

  return body as ResolveResponse;
}

export async function submitRsvp(rawToken: string, payload: {
  responses: Array<{ event_id: string; response_status: 'ATTENDING' | 'NOT_ATTENDING'; attending_count: number }>;
  optional_fields: Record<string, unknown>;
}, options: RequestOptions = {}): Promise<RsvpSubmitResponse> {
  const endpoint = import.meta.env.VITE_INVITATION_RSVP_URL ?? '/v1/invitation/rsvp';
  let response: Response;
  try {
    response = await fetchWithTimeout(endpoint, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, cache: 'no-store',
      body: JSON.stringify({ raw_token: rawToken, ...payload }),
    }, RSVP_TIMEOUT_MS, options);
  } catch {
    return { ok: false, error_code: 'TEMPORARY_UNAVAILABLE' };
  }
  const body = await response.json().catch(() => null);
  if (body?.ok === true) return body as RsvpSubmitResponse;
  if (response.status === 429) return { ok: false, error_code: 'RATE_LIMITED' };
  if (response.status === 403) return { ok: false, error_code: 'RSVP_CLOSED' };
  if (response.status === 400 && body?.error_code === 'EVENT_NOT_AVAILABLE') return { ok: false, error_code: 'EVENT_NOT_AVAILABLE' };
  if (response.status === 400) return { ok: false, error_code: 'INVALID_RESPONSE' };
  if (response.status >= 500) return { ok: false, error_code: 'TEMPORARY_UNAVAILABLE' };
  return { ok: false, error_code: 'INVITATION_UNAVAILABLE' };
}
