import { beginWeddingDelete } from './index.ts';

Deno.test('rejects non-POST without invoking trusted services', async () => {
  const response = await beginWeddingDelete(new Request('http://local', { method: 'GET' }));
  if (response.status !== 405) throw new Error('expected 405');
});

Deno.test('denies missing bearer token', async () => {
  const response = await beginWeddingDelete(new Request('http://local', { method: 'POST', body: '{}' }));
  if (response.status !== 401) throw new Error('expected 401');
});

Deno.test('uses verified auth id rather than request actor field', async () => {
  const original = globalThis.fetch;
  const calls: RequestInit[] = [];
  Deno.env.set('SUPABASE_URL', 'http://supabase.local');
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'test-server-key');
  globalThis.fetch = async (input, init) => {
    calls.push(init ?? {});
    if (String(input).includes('/auth/v1/user')) return new Response(JSON.stringify({ id: 'verified-owner' }));
    return new Response(JSON.stringify({ status: 'DELETING' }));
  };
  try {
    const response = await beginWeddingDelete(new Request('http://local', { method: 'POST', headers: { authorization: 'Bearer valid' }, body: JSON.stringify({ wedding_id: 'wedding-id', actor_user_id: 'attacker' }) }));
    if (response.status !== 202 || calls.length !== 2) throw new Error('expected guarded delete');
    const bridgeBody = JSON.parse(String(calls[1].body));
    if (bridgeBody.p_verified_actor_user_id !== 'verified-owner') throw new Error('actor override accepted');
  } finally { globalThis.fetch = original; }
});
