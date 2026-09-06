import { describe, expect, it, vi } from 'vitest';

import { proxyInvitationRequest } from './invitation_proxy';

const environment = {
  SUPABASE_FUNCTIONS_ORIGIN: 'https://example.supabase.co',
  SUPABASE_ANON_KEY: 'publishable-test-key',
  WEDDINGOS_GATEWAY_PROOF: 'test-gateway-proof',
};

describe('Cloudflare invitation proxy', () => {
  it('uses a fixed resolve target and forwards only the provider IP signal', async () => {
    const fetcher = vi.fn(async () => new Response('ok'));
    await proxyInvitationRequest(new Request('https://guest.example/v1/invitation/resolve', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        origin: 'https://guest.example',
        'cf-connecting-ip': '198.51.100.10',
        'x-forwarded-for': '203.0.113.1',
        'x-real-ip': '203.0.113.2',
        forwarded: 'for=203.0.113.3',
        'x-weddingos-gateway-proof': 'attacker-supplied-proof',
      },
      body: '{}',
    }), environment, 'invitation-resolve', fetcher);

    const [target, init] = fetcher.mock.calls[0];
    expect(target.toString()).toBe('https://example.supabase.co/functions/v1/invitation-resolve');
    expect(new Headers(init?.headers).get('cf-connecting-ip')).toBe('198.51.100.10');
    expect(new Headers(init?.headers).get('x-forwarded-for')).toBeNull();
    expect(new Headers(init?.headers).get('x-real-ip')).toBeNull();
    expect(new Headers(init?.headers).get('forwarded')).toBeNull();
    expect(new Headers(init?.headers).get('x-weddingos-gateway-proof')).toBe('test-gateway-proof');
  });

  it('does not accept a client-selected function target', async () => {
    const fetcher = vi.fn(async () => new Response('ok'));
    await proxyInvitationRequest(new Request('https://guest.example/v1/invitation/rsvp', { method: 'POST', body: '{}' }), environment, 'invitation-rsvp', fetcher);
    const [target] = fetcher.mock.calls[0];
    expect(target.toString()).toBe('https://example.supabase.co/functions/v1/invitation-rsvp');
  });

  it('fails closed when the controlled upstream configuration is invalid', async () => {
    const response = await proxyInvitationRequest(new Request('https://guest.example/v1/invitation/resolve', { method: 'POST' }), {
      SUPABASE_FUNCTIONS_ORIGIN: 'http://not-secure.example',
      SUPABASE_ANON_KEY: 'publishable-test-key',
    }, 'invitation-resolve');
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ ok: false, error_code: 'TEMPORARY_ERROR' });
  });
});
