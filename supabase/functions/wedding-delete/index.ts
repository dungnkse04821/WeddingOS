import { BoundedBodyError, createCorrelationId, type Fetcher, fetchWithDeadline, readBoundedJson, readBoundedResponseJson } from '../_shared/edge_safety.ts';
import {
  logEdgeCompletion,
  logWeddingDeleteStageFailure,
  type WeddingDeleteFailureStage,
} from '../_shared/operational_log.ts';

const json = (body: unknown, status = 200, requestId = createCorrelationId()) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Request-ID': requestId,
    },
  });

const STORAGE_BUCKET = 'wedding_media';
const STORAGE_PAGE_SIZE = 100;
const STORAGE_DELETE_BATCH_SIZE = 100;
export const DELETE_BODY_LIMIT_BYTES = 2 * 1024;
export const AUTH_TIMEOUT_MS = 5_000;
export const PROVIDER_TIMEOUT_MS = 8_000;
const AUTH_RESPONSE_LIMIT_BYTES = 64 * 1024;
const PROVIDER_RESPONSE_LIMIT_BYTES = 1024 * 1024;
const STORAGE_LIST_RESPONSE_LIMIT_BYTES = 512 * 1024;

export type StorageEntry = { name?: unknown; id?: unknown };
type StorageClient = Fetcher;

class WeddingDeleteStageError extends Error {
  constructor(readonly stage: WeddingDeleteFailureStage) {
    super(stage);
  }
}

function storageHeaders(serviceKey: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };
}

function childPath(prefix: string, name: unknown): string {
  if (
    typeof name !== 'string' || !name || name.startsWith('/') ||
    name.split('/').includes('..')
  ) throw new Error('unsafe storage list result');
  return `${prefix}${name}`;
}

async function listDirectory(
  url: string,
  serviceKey: string,
  prefix: string,
  fetcher: StorageClient,
): Promise<StorageEntry[]> {
  try {
    const entries: StorageEntry[] = [];
    for (let offset = 0;; offset += STORAGE_PAGE_SIZE) {
      const response = await fetchWithDeadline(
        fetcher,
        `${url}/storage/v1/object/list/${STORAGE_BUCKET}`,
        {
          method: 'POST',
          headers: storageHeaders(serviceKey),
          body: JSON.stringify({
            prefix,
            limit: STORAGE_PAGE_SIZE,
            offset,
            sortBy: { column: 'name', order: 'asc' },
          }),
        },
        PROVIDER_TIMEOUT_MS,
      );
      if (!response.ok) throw new Error('storage list failed');
      const page = await readBoundedResponseJson(
        response,
        STORAGE_LIST_RESPONSE_LIMIT_BYTES,
      );
      if (!Array.isArray(page)) throw new Error('invalid storage list response');
      entries.push(...page);
      if (page.length < STORAGE_PAGE_SIZE) return entries;
    }
  } catch (_) {
    throw new WeddingDeleteStageError('storage_list');
  }
}

async function listPrefixObjects(
  url: string,
  serviceKey: string,
  prefix: string,
  fetcher: StorageClient,
): Promise<string[]> {
  const objects: string[] = [];
  const visit = async (directory: string): Promise<void> => {
    for (
      const entry of await listDirectory(url, serviceKey, directory, fetcher)
    ) {
      const path = childPath(directory, entry.name);
      if (typeof entry.id === 'string') objects.push(path);
      else await visit(`${path}/`);
    }
  };
  await visit(prefix);
  return objects;
}

export async function cleanupWeddingStorage(
  url: string,
  serviceKey: string,
  weddingId: string,
  fetcher: StorageClient = fetch,
): Promise<void> {
  const prefix = `weddings/${weddingId}/`;
  for (;;) {
    const objects = await listPrefixObjects(url, serviceKey, prefix, fetcher);
    if (objects.length === 0) return;
    for (
      let start = 0;
      start < objects.length;
      start += STORAGE_DELETE_BATCH_SIZE
    ) {
      const response = await fetchWithDeadline(
        fetcher,
        `${url}/storage/v1/object/${STORAGE_BUCKET}`,
        {
          method: 'DELETE',
          headers: storageHeaders(serviceKey),
          body: JSON.stringify({
            prefixes: objects.slice(start, start + STORAGE_DELETE_BATCH_SIZE),
          }),
        },
        PROVIDER_TIMEOUT_MS,
      );
      if (!response.ok) throw new WeddingDeleteStageError('storage_cleanup');
    }
  }
}

async function callBridge(
  url: string,
  serviceKey: string,
  name: string,
  weddingId: string,
  actor: string,
): Promise<{ ok: boolean; body?: Record<string, unknown>; status?: number }> {
  const response = await fetchWithDeadline(
    fetch,
    `${url}/rest/v1/rpc/${name}`,
    {
      method: 'POST',
      headers: {
        ...storageHeaders(serviceKey),
        'Accept-Profile': 'edge_api',
        'Content-Profile': 'edge_api',
      },
      body: JSON.stringify({
        p_wedding_id: weddingId,
        p_verified_actor_user_id: actor,
      }),
    },
    PROVIDER_TIMEOUT_MS,
  );
  if (!response.ok) return { ok: false, status: response.status };
  const body = await readBoundedResponseJson(
    response,
    PROVIDER_RESPONSE_LIMIT_BYTES,
  );
  return {
    ok: true,
    body: body && typeof body === 'object' ? body as Record<string, unknown> : undefined,
    status: response.status,
  };
}

// DB begin/finalize remain the lifecycle authority; Storage must be freshly
// verified empty between those calls.
export async function beginWeddingDelete(request: Request): Promise<Response> {
  const requestId = createCorrelationId();
  const startedAt = performance.now();
  try {
    const response = await beginWeddingDeleteCore(request, requestId);
    logEdgeCompletion('wedding_delete', requestId, startedAt, response.status);
    return response;
  } catch (_) {
    const response = json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 503, requestId);
    logEdgeCompletion('wedding_delete', requestId, startedAt, response.status, console.log, true);
    return response;
  }
}

async function beginWeddingDeleteCore(
  request: Request,
  requestId: string,
): Promise<Response> {
  if (request.method !== 'POST') {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 405, requestId);
  }
  const token = request.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)
    ?.[1];
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token) {
    return json({ ok: false, error_code: 'UNAUTHORIZED' }, 401, requestId);
  }
  if (!url || !serviceKey) {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 503, requestId);
  }
  let weddingId: unknown;
  try {
    weddingId = (await readBoundedJson(request, DELETE_BODY_LIMIT_BYTES) as Record<
      string,
      unknown
    >)?.wedding_id;
  } catch (error) {
    const status = error instanceof BoundedBodyError && error.kind === 'too_large' ? 413 : 400;
    return json(
      { ok: false, error_code: 'TEMPORARY_ERROR' },
      status,
      requestId,
    );
  }
  if (typeof weddingId !== 'string') {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 400, requestId);
  }

  let verified: Response;
  try {
    verified = await fetchWithDeadline(fetch, `${url}/auth/v1/user`, {
      headers: { apikey: serviceKey, Authorization: `Bearer ${token}` },
    }, AUTH_TIMEOUT_MS);
  } catch (_) {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 503, requestId);
  }
  if (!verified.ok) {
    return json({ ok: false, error_code: 'UNAUTHORIZED' }, 401, requestId);
  }
  let actor: unknown;
  try {
    actor = (await readBoundedResponseJson(
      verified,
      AUTH_RESPONSE_LIMIT_BYTES,
    ) as Record<string, unknown>)?.id;
  } catch (_) {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 503, requestId);
  }
  if (typeof actor !== 'string') {
    return json({ ok: false, error_code: 'TEMPORARY_ERROR' }, 400, requestId);
  }

  let begin: { ok: boolean; body?: Record<string, unknown>; status?: number };
  try {
    begin = await callBridge(
      url,
      serviceKey,
      'begin_wedding_delete',
      weddingId,
      actor,
    );
  } catch (_) {
    logWeddingDeleteStageFailure(requestId, 'begin_bridge');
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      503,
      requestId,
    );
  }
  if (!begin.ok) {
    logWeddingDeleteStageFailure(requestId, 'begin_bridge', begin.status);
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      403,
      requestId,
    );
  }
  if (begin.body?.status === 'DELETED') {
    return json({ ok: true, status: 'DELETED' }, 200, requestId);
  }
  const authoritativeWeddingId = begin.body?.wedding_id;
  if (typeof authoritativeWeddingId !== 'string') {
    logWeddingDeleteStageFailure(requestId, 'begin_bridge', begin.status);
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      503,
      requestId,
    );
  }
  try {
    await cleanupWeddingStorage(url, serviceKey, authoritativeWeddingId);
  } catch (error) {
    logWeddingDeleteStageFailure(
      requestId,
      error instanceof WeddingDeleteStageError ? error.stage : 'storage_cleanup',
    );
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      503,
      requestId,
    );
  }
  let finalized: { ok: boolean; body?: Record<string, unknown>; status?: number };
  try {
    finalized = await callBridge(
      url,
      serviceKey,
      'finalize_wedding_delete',
      authoritativeWeddingId,
      actor,
    );
  } catch (_) {
    logWeddingDeleteStageFailure(requestId, 'finalize_bridge');
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      503,
      requestId,
    );
  }
  if (!finalized.ok || finalized.body?.status !== 'DELETED') {
    logWeddingDeleteStageFailure(requestId, 'finalize_bridge', finalized.status);
    return json(
      { ok: false, error_code: 'DELETE_RETRY_REQUIRED' },
      503,
      requestId,
    );
  }
  return json({ ok: true, status: 'DELETED' }, 200, requestId);
}
if (import.meta.main) Deno.serve(beginWeddingDelete);
