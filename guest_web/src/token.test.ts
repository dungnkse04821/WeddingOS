import { describe, expect, it, vi } from 'vitest';

import {
  bootstrapInvitationToken,
  extractTokenFromHash,
  tokenStorageKeyForTests,
} from './token';

const token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345';

describe('Guest Web token bootstrap', () => {
  it('extracts token from approved invite fragment', () => {
    expect(extractTokenFromHash(`#/invite/${token}`)).toBe(token);
    expect(extractTokenFromHash(`#/invitation/${token}`)).toBeNull();
    expect(extractTokenFromHash(`?token=${token}`)).toBeNull();
  });

  it('scrubs token-bearing URL and stores only in sessionStorage', () => {
    window.history.replaceState(null, '', `/#/invite/${token}`);
    const replaceSpy = vi.spyOn(window.history, 'replaceState');

    const result = bootstrapInvitationToken(window);

    expect(result).toEqual({ ok: true, rawToken: token, source: 'fragment' });
    expect(window.location.hash).toBe('');
    expect(window.sessionStorage.getItem(tokenStorageKeyForTests)).toBe(token);
    expect(window.localStorage.length).toBe(0);
    expect(replaceSpy).toHaveBeenCalled();
  });

  it('recovers from same-tab sessionStorage without localStorage', () => {
    window.history.replaceState(null, '', '/');
    window.sessionStorage.setItem(tokenStorageKeyForTests, token);

    const result = bootstrapInvitationToken(window);

    expect(result).toEqual({ ok: true, rawToken: token, source: 'session' });
    expect(window.localStorage.length).toBe(0);
  });
});
