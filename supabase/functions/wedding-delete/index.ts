const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

const STORAGE_BUCKET = 'wedding_media';
const STORAGE_PAGE_SIZE = 100;
const STORAGE_DELETE_BATCH_SIZE = 100;

export type StorageEntry = { name?: unknown; id?: unknown };
type StorageClient = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

function storageHeaders(serviceKey: string): HeadersInit {
  return { 'Content-Type': 'application/json', apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
}

function childPath(prefix: string, name: unknown): string {
  if (typeof name !== 'string' || !name || name.startsWith('/') || name.split('/').includes('..')) throw new Error('unsafe storage list result');
  return `${prefix}${name}`;
}

async function listDirectory(url: string, serviceKey: string, prefix: string, fetcher: StorageClient): Promise<StorageEntry[]> {
  const entries: StorageEntry[] = [];
  for (let offset = 0;; offset += STORAGE_PAGE_SIZE) {
    const response = await fetcher(`${url}/storage/v1/object/list/${STORAGE_BUCKET}`, {
      method: 'POST', headers: storageHeaders(serviceKey),
      body: JSON.stringify({ prefix, limit: STORAGE_PAGE_SIZE, offset, sortBy: { column: 'name', order: 'asc' } }),
    });
    if (!response.ok) throw new Error('storage list failed');
    const page = await response.json();
    if (!Array.isArray(page)) throw new Error('invalid storage list response');
    entries.push(...page);
    if (page.length < STORAGE_PAGE_SIZE) return entries;
  }
}

async function listPrefixObjects(url: string, serviceKey: string, prefix: string, fetcher: StorageClient): Promise<string[]> {
  const objects: string[] = [];
  const visit = async (directory: string): Promise<void> => {
    for (const entry of await listDirectory(url, serviceKey, directory, fetcher)) {
      const path = childPath(directory, entry.name);
      if (typeof entry.id === 'string') objects.push(path); else await visit(`${path}/`);
    }
  };
  await visit(prefix);
  return objects;
}

export async function cleanupWeddingStorage(url: string, serviceKey: string, weddingId: string, fetcher: StorageClient = fetch): Promise<void> {
  const prefix = `weddings/${weddingId}/`;
  for (;;) {
    const objects = await listPrefixObjects(url, serviceKey, prefix, fetcher);
    if (objects.length === 0) return;
    for (let start = 0; start < objects.length; start += STORAGE_DELETE_BATCH_SIZE) {
      const response = await fetcher(`${url}/storage/v1/object/${STORAGE_BUCKET}`, {
        method: 'DELETE', headers: storageHeaders(serviceKey), body: JSON.stringify({ prefixes: objects.slice(start, start + STORAGE_DELETE_BATCH_SIZE) }),
      });
      if (!response.ok) throw new Error('storage delete failed');
    }
  }
}

async function callBridge(url: string, serviceKey: string, name: string, weddingId: string, actor: string): Promise<{ ok: boolean; body?: Record<string, unknown> }> {
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST', headers: { ...storageHeaders(serviceKey), 'Accept-Profile': 'edge_api', 'Content-Profile': 'edge_api' },
    body: JSON.stringify({ p_wedding_id: weddingId, p_verified_actor_user_id: actor }),
  });
  if (!response.ok) return { ok: false };
  const body = await response.json();
  return { ok: true, body: body && typeof body === 'object' ? body : undefined };
}

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
  const begin = await callBridge(url, serviceKey, 'begin_wedding_delete', weddingId, actor);
  if (!begin.ok) return json({ ok: false, error_code: 'DELETE_RETRY_REQUIRED' }, 403);
  if (begin.body?.status === 'DELETED') return json({ ok: true, status: 'DELETED' });
  const authoritativeWeddingId = begin.body?.wedding_id;
  if (typeof authoritativeWeddingId !== 'string') return json({ ok: false, error_code: 'DELETE_RETRY_REQUIRED' }, 503);
  try { await cleanupWeddingStorage(url, serviceKey, authoritativeWeddingId); } catch (_) { return json({ ok: false, error_code: 'DELETE_RETRY_REQUIRED' }, 503); }
  const finalized = await callBridge(url, serviceKey, 'finalize_wedding_delete', authoritativeWeddingId, actor);
  if (!finalized.ok || finalized.body?.status !== 'DELETED') return json({ ok: false, error_code: 'DELETE_RETRY_REQUIRED' }, 503);
  return json({ ok: true, status: 'DELETED' });
}
if (import.meta.main) Deno.serve(beginWeddingDelete);
