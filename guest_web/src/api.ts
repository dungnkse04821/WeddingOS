import type { ResolveResponse, RsvpSubmitResponse } from './types';

const defaultEndpoint = '/v1/invitation/resolve';

export async function resolveInvitation(rawToken: string): Promise<ResolveResponse> {
  const endpoint = import.meta.env.VITE_INVITATION_RESOLVE_URL ?? defaultEndpoint;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    cache: 'no-store',
    body: JSON.stringify({ raw_token: rawToken }),
  });

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
}): Promise<RsvpSubmitResponse> {
  const endpoint = import.meta.env.VITE_INVITATION_RSVP_URL ?? '/v1/invitation/rsvp';
  const response = await fetch(endpoint, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, cache: 'no-store',
    body: JSON.stringify({ raw_token: rawToken, ...payload }),
  });
  const body = await response.json().catch(() => null);
  if (body?.ok === true) return body as RsvpSubmitResponse;
  if (response.status === 429) return { ok: false, error_code: 'RATE_LIMITED' };
  if (response.status === 403) return { ok: false, error_code: 'RSVP_CLOSED' };
  if (response.status === 400 && body?.error_code === 'EVENT_NOT_AVAILABLE') return { ok: false, error_code: 'EVENT_NOT_AVAILABLE' };
  if (response.status === 400) return { ok: false, error_code: 'INVALID_RESPONSE' };
  if (response.status >= 500) return { ok: false, error_code: 'TEMPORARY_UNAVAILABLE' };
  return { ok: false, error_code: 'INVITATION_UNAVAILABLE' };
}
