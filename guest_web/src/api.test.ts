import { describe, expect, it, vi } from 'vitest';

import { resolveInvitation, RESOLVE_TIMEOUT_MS, RSVP_TIMEOUT_MS, submitRsvp } from './api';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

function abortingFetcher() {
  return vi.fn((_input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => new Promise<Response>((_resolve, reject) => {
    init?.signal?.addEventListener('abort', () => reject(new DOMException('provider detail', 'AbortError')));
  }));
}

describe('Guest API reliability', () => {
  it('bounds invitation resolve and maps timeout details to a safe retry result', async () => {
    const fetcher = abortingFetcher();
    let configuredDelay = 0;
    const result = await resolveInvitation(token, {
      fetcher,
      schedule: (callback, delay) => {
        configuredDelay = delay ?? 0;
        if (typeof callback === 'function') queueMicrotask(() => callback());
        return 1;
      },
      cancel: () => undefined,
    });
    expect(configuredDelay).toBe(RESOLVE_TIMEOUT_MS);
    expect(result).toEqual({ ok: false, error_code: 'TEMPORARY_ERROR' });
    expect(JSON.stringify(result)).not.toContain('provider detail');
  });

  it('bounds RSVP without automatically replaying a timed-out write', async () => {
    const fetcher = abortingFetcher();
    let configuredDelay = 0;
    const result = await submitRsvp(token, {
      responses: [{ event_id: 'e1000000-0000-4000-8000-000000000001', response_status: 'ATTENDING', attending_count: 1 }],
      optional_fields: {},
    }, {
      fetcher,
      schedule: (callback, delay) => {
        configuredDelay = delay ?? 0;
        if (typeof callback === 'function') queueMicrotask(() => callback());
        return 1;
      },
      cancel: () => undefined,
    });
    expect(configuredDelay).toBe(RSVP_TIMEOUT_MS);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(result).toEqual({ ok: false, error_code: 'TEMPORARY_UNAVAILABLE' });
  });

  it('maps ordinary network failures without exposing browser diagnostics', async () => {
    const result = await resolveInvitation(token, {
      fetcher: vi.fn(async () => { throw new TypeError('Failed to fetch https://provider.example'); }),
    });
    expect(result).toEqual({ ok: false, error_code: 'TEMPORARY_ERROR' });
    expect(JSON.stringify(result)).not.toContain('provider.example');
  });
});
