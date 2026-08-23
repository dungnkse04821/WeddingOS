import type { ResolveResponse } from './types';

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
