#!/usr/bin/env node

import { pathToFileURL } from 'node:url';

const REQUIRED_ENVIRONMENT = [
  'STAGING_SUPABASE_URL',
  'STAGING_SUPABASE_ANON_KEY',
  'STAGING_ORGANIZER_ACCESS_TOKEN',
];
const DEFAULT_GUEST_ORIGIN = 'https://weddingos-staging.pages.dev';

export function requiredConfiguration(environment = process.env) {
  return REQUIRED_ENVIRONMENT.filter((name) => !environment[name]?.trim());
}

export function fixtureConfig(environment = process.env) {
  const missing = requiredConfiguration(environment);
  if (missing.length > 0) {
    throw new Error(`Missing required staging configuration: ${missing.join(', ')}`);
  }

  const supabaseUrl = new URL(environment.STAGING_SUPABASE_URL);
  if (supabaseUrl.protocol !== 'https:') {
    throw new Error('STAGING_SUPABASE_URL must use HTTPS.');
  }
  const guestOrigin = new URL(environment.STAGING_GUEST_WEB_ORIGIN ?? DEFAULT_GUEST_ORIGIN);
  if (guestOrigin.protocol !== 'https:') {
    throw new Error('STAGING_GUEST_WEB_ORIGIN must use HTTPS.');
  }

  return {
    supabaseUrl: supabaseUrl.toString().replace(/\/$/, ''),
    anonKey: environment.STAGING_SUPABASE_ANON_KEY.trim(),
    organizerToken: environment.STAGING_ORGANIZER_ACCESS_TOKEN.trim(),
    guestOrigin: guestOrigin.toString().replace(/\/$/, ''),
  };
}

function isoDateAfter(days) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function organizerHeaders(config, profile) {
  return {
    apikey: config.anonKey,
    Authorization: `Bearer ${config.organizerToken}`,
    ...(profile ? { 'Accept-Profile': profile, 'Content-Profile': profile } : {}),
    'Content-Type': 'application/json',
  };
}

async function requestJson(url, init, description) {
  const response = await fetch(url, init);
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(`${description} failed with HTTP ${response.status}.`);
  }
  return body;
}

async function organizerRpc(config, name, payload) {
  return requestJson(
    `${config.supabaseUrl}/rest/v1/rpc/${name}`,
    { method: 'POST', headers: organizerHeaders(config, 'api_v1'), body: JSON.stringify(payload) },
    `RPC ${name}`,
  );
}

async function organizerInsert(config, table, payload) {
  return requestJson(
    `${config.supabaseUrl}/rest/v1/${table}`,
    {
      method: 'POST',
      headers: { ...organizerHeaders(config), Prefer: 'return=representation' },
      body: JSON.stringify(payload),
    },
    `Insert ${table}`,
  );
}

async function organizerUpdate(config, table, id, payload) {
  return requestJson(
    `${config.supabaseUrl}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`,
    {
      method: 'PATCH',
      headers: { ...organizerHeaders(config), Prefer: 'return=representation' },
      body: JSON.stringify(payload),
    },
    `Update ${table}`,
  );
}

async function guestPost(config, path, payload) {
  return requestJson(
    `${config.guestOrigin}${path}`,
    {
      method: 'POST',
      headers: { Origin: config.guestOrigin, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    },
    `Guest route ${path}`,
  );
}

async function guestUnavailable(config, path, payload, description) {
  const response = await fetch(`${config.guestOrigin}${path}`, {
    method: 'POST',
    headers: { Origin: config.guestOrigin, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await response.json().catch(() => null);
  if (response.status !== 404 || body?.error_code !== 'INVITATION_UNAVAILABLE') {
    throw new Error(`${description} did not fail closed.`);
  }
}

export async function createAndVerifyFixture(config, { cleanup = false } = {}) {
  const eventDate = isoDateAfter(7);
  const weddingResult = await organizerRpc(config, 'create_wedding', {
    p_request_id: crypto.randomUUID(),
    p_name: 'WeddingOS Staging Test',
    p_cultural_context: 'TUY_CHON',
    p_exact_date: eventDate,
    p_expected_year: null,
    p_expected_month: null,
    p_timezone: 'Asia/Ho_Chi_Minh',
    p_target_budget: null,
  });
  const weddingId = weddingResult.wedding?.id;
  if (!weddingId) throw new Error('create_wedding did not return a Wedding ID.');

  const [event] = await organizerInsert(config, 'wedding_events', {
    wedding_id: weddingId,
    name: 'Lễ cưới thử nghiệm',
    exact_date: eventDate,
    location: 'Không gian thử nghiệm',
    map_link: 'https://maps.example/staging-fixture',
    is_main_event: true,
  });
  const [party] = await organizerInsert(config, 'invitation_parties', {
    wedding_id: weddingId,
    display_name: 'Gia đình Test',
    invited_count: 1,
  });
  await organizerInsert(config, 'guests', {
    wedding_id: weddingId,
    invitation_party_id: party.id,
    name: 'Khách Test',
    side: 'COMMON',
    guest_source: 'OTHER',
  });
  const [invitation] = await organizerInsert(config, 'invitations', {
    wedding_id: weddingId,
    invitation_party_id: party.id,
  });
  await organizerInsert(config, 'invitation_event_targetings', {
    wedding_id: weddingId,
    invitation_id: invitation.id,
    wedding_event_id: event.id,
  });
  await organizerUpdate(config, 'invitations', invitation.id, { status: 'READY' });

  const credential = await organizerRpc(config, 'regenerate_invitation_credential', {
    p_invitation_id: invitation.id,
  });
  const rawToken = credential.raw_token;
  if (typeof rawToken !== 'string' || rawToken.length !== 43) {
    throw new Error('Credential generation did not return an in-memory Class-D token.');
  }

  const resolve = await guestPost(config, '/v1/invitation/resolve', { raw_token: rawToken });
  const eventId = resolve.invitation?.events?.[0]?.id;
  if (!resolve.ok || !eventId) throw new Error('Guest resolve did not return an RSVP-ready Event.');
  const rsvp = await guestPost(config, '/v1/invitation/rsvp', {
    raw_token: rawToken,
    responses: [{ event_id: eventId, response_status: 'ATTENDING', attending_count: 1 }],
    optional_fields: {},
  });
  if (!rsvp.ok) throw new Error('Guest RSVP did not succeed.');
  const reload = await guestPost(config, '/v1/invitation/resolve', { raw_token: rawToken });
  if (!reload.ok || reload.invitation?.rsvp?.summary !== 'RESPONDED') {
    throw new Error('Guest reload did not return current RSVP state.');
  }
  const invalidToken = `${rawToken.slice(0, -1)}${rawToken.endsWith('A') ? 'B' : 'A'}`;
  await guestUnavailable(config, '/v1/invitation/resolve', { raw_token: invalidToken }, 'Invalid credential');

  // Regeneration revokes the first token through the approved organizer RPC.
  await organizerRpc(config, 'regenerate_invitation_credential', { p_invitation_id: invitation.id });
  await guestUnavailable(config, '/v1/invitation/resolve', { raw_token: rawToken }, 'Revoked credential');

  if (cleanup) {
    await requestJson(
      `${config.supabaseUrl}/functions/v1/wedding-delete`,
      { method: 'POST', headers: organizerHeaders(config), body: JSON.stringify({ wedding_id: weddingId }) },
      'Wedding cleanup',
    );
  }

  return { weddingId, eventId: event.id, invitationId: invitation.id, cleanupRequested: cleanup };
}

const isMainModule = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  try {
    const config = fixtureConfig();
    const result = await createAndVerifyFixture(config, { cleanup: process.argv.includes('--cleanup') });
    console.log(JSON.stringify({ status: 'PASS', ...result }));
  } catch (error) {
    console.error(error instanceof Error ? error.message : 'Staging fixture failed.');
    process.exitCode = 1;
  }
}
