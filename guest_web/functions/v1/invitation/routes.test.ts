import { describe, expect, it } from 'vitest';

import { onRequest as resolve } from './resolve';
import { onRequest as rsvp } from './rsvp';

describe('Cloudflare invitation route entrypoints', () => {
  it('resolves both entrypoint imports and preserves the POST-only boundary', async () => {
    const context = { request: new Request('https://guest.example/v1/invitation/resolve') };
    expect((await resolve(context)).status).toBe(405);
    expect((await rsvp(context)).status).toBe(405);
  });
});
