const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

// M7.2B1 deliberately stops after the DB lifecycle transition. M7.2B2 adds
// Storage cleanup before this route is allowed to call the finalize bridge.
export async function beginWeddingDelete(request: Request): Promise<Response> {
  if (request.method !== 'POST') return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 405);
  const token = request.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token) return json({ ok: false, error_code: 'UNAUTHORIZED' }, 401);
  if (!url || !serviceKey) return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 503);
  const verified = await fetch(`${url}/auth/v1/user`, { headers: { apikey: serviceKey, Authorization: `Bearer ${token}` } });
  if (!verified.ok) return json({ ok: false, error_code: 'UNAUTHORIZED' }, 401);
  const actor = (await verified.json())?.id;
  let weddingId: unknown;
  try { weddingId = (await request.json())?.wedding_id; } catch (_) { return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 400); }
  if (typeof actor !== 'string' || typeof weddingId !== 'string') return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 400);
  const bridge = await fetch(`${url}/rest/v1/rpc/begin_wedding_delete`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept-Profile': 'edge_api', 'Content-Profile': 'edge_api', apikey: serviceKey, Authorization: `Bearer ${serviceKey}` }, body: JSON.stringify({ p_wedding_id: weddingId, p_verified_actor_user_id: actor }) });
  if (!bridge.ok) return json({ ok: false, error_code: 'DELETE_RETRY_REQUIRED' }, 403);
  return json({ ok: true, status: 'DELETING' }, 202);
}
if (import.meta.main) Deno.serve(beginWeddingDelete);
