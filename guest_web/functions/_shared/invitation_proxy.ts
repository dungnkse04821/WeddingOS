export type ProxyEnvironment = {
  SUPABASE_FUNCTIONS_ORIGIN?: string;
  SUPABASE_ANON_KEY?: string;
};

const ALLOWED_METHODS = new Set(['POST', 'OPTIONS']);

function configuredTarget(
  environment: ProxyEnvironment,
  functionName: 'invitation-resolve' | 'invitation-rsvp',
): URL | null {
  const origin = environment.SUPABASE_FUNCTIONS_ORIGIN?.trim();
  if (!origin) return null;

  try {
    const target = new URL(`/functions/v1/${functionName}`, origin);
    return target.protocol === 'https:' ? target : null;
  } catch {
    return null;
  }
}

export async function proxyInvitationRequest(
  request: Request,
  environment: ProxyEnvironment,
  functionName: 'invitation-resolve' | 'invitation-rsvp',
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  if (!ALLOWED_METHODS.has(request.method)) {
    return new Response(null, { status: 405, headers: { Allow: 'POST, OPTIONS' } });
  }

  const target = configuredTarget(environment, functionName);
  const anonKey = environment.SUPABASE_ANON_KEY?.trim();
  if (!target || !anonKey) {
    return new Response(JSON.stringify({ ok: false, error_code: 'TEMPORARY_ERROR' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
    });
  }

  // The route and target are fixed. Never forward client-selected forwarding headers.
  const headers = new Headers({ apikey: anonKey });
  const contentType = request.headers.get('content-type');
  const origin = request.headers.get('origin');
  const cloudflareIp = request.headers.get('cf-connecting-ip');
  if (contentType) headers.set('content-type', contentType);
  if (origin) headers.set('origin', origin);
  if (cloudflareIp) headers.set('cf-connecting-ip', cloudflareIp);

  return fetcher(target, {
    method: request.method,
    headers,
    body: request.method === 'POST' ? request.body : undefined,
  });
}
