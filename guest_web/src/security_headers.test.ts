import { describe, expect, it } from 'vitest';

import headers from '../public/_headers?raw';

describe('Cloudflare Pages security headers', () => {
  it('commits a restrictive CSP and browser security policy', () => {
    const csp = headers.match(/Content-Security-Policy: ([^\n]+)/)?.[1] ?? '';
    expect(headers).toContain("default-src 'self'");
    expect(headers).toContain("script-src 'self'");
    expect(headers).not.toContain('unsafe-eval');
    expect(csp.match(/script-src ([^;]+)/)?.[1]).not.toContain('*');
    expect(headers).toContain("frame-ancestors 'none'");
    expect(csp.match(/connect-src ([^;]+)/)?.[1]).toBe("'self'");
    expect(headers).toContain('X-Content-Type-Options: nosniff');
    expect(headers).toContain('Referrer-Policy: no-referrer');
    expect(headers).toContain('Permissions-Policy:');
  });

  it('does not cache the app shell and caches only hashed assets immutably', () => {
    expect(headers).toContain('Cache-Control: no-store');
    expect(headers).toContain('/assets/*');
    expect(headers).toContain('Cache-Control: public, max-age=31536000, immutable');
  });
});
