const SESSION_TOKEN_KEY = 'weddingos.invitation.raw_token';
const INVITE_PREFIX = '#/invite/';
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export type TokenBootstrapResult =
  | { ok: true; rawToken: string; source: 'fragment' | 'session' }
  | { ok: false };

export function extractTokenFromHash(hash: string): string | null {
  if (!hash.startsWith(INVITE_PREFIX)) return null;
  const token = hash.slice(INVITE_PREFIX.length).split(/[/?#]/)[0] ?? '';
  return TOKEN_PATTERN.test(token) ? token : null;
}

export function scrubInvitationUrl(win: Window): void {
  win.history.replaceState(null, document.title, `${win.location.pathname}${win.location.search}`);
}

export function storeSessionToken(win: Window, rawToken: string): void {
  win.sessionStorage.setItem(SESSION_TOKEN_KEY, rawToken);
}

export function clearSessionToken(win: Window): void {
  win.sessionStorage.removeItem(SESSION_TOKEN_KEY);
}

export function getSessionToken(win: Window): string | null {
  const token = win.sessionStorage.getItem(SESSION_TOKEN_KEY);
  return token && TOKEN_PATTERN.test(token) ? token : null;
}

export function bootstrapInvitationToken(win: Window): TokenBootstrapResult {
  const fragmentToken = extractTokenFromHash(win.location.hash);
  if (fragmentToken) {
    storeSessionToken(win, fragmentToken);
    scrubInvitationUrl(win);
    return { ok: true, rawToken: fragmentToken, source: 'fragment' };
  }

  const sessionToken = getSessionToken(win);
  if (sessionToken) {
    return { ok: true, rawToken: sessionToken, source: 'session' };
  }

  return { ok: false };
}

export const tokenStorageKeyForTests = SESSION_TOKEN_KEY;
