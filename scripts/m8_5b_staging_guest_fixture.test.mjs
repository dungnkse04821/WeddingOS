import assert from 'node:assert/strict';
import test from 'node:test';

import { fixtureConfig, requiredConfiguration } from './m8_5b_staging_guest_fixture.mjs';

test('requires operator-provided public staging and organizer session inputs', () => {
  assert.deepEqual(requiredConfiguration({}), [
    'STAGING_SUPABASE_URL',
    'STAGING_SUPABASE_ANON_KEY',
    'STAGING_ORGANIZER_ACCESS_TOKEN',
  ]);
});

test('accepts only HTTPS staging origins without emitting credentials', () => {
  const config = fixtureConfig({
    STAGING_SUPABASE_URL: 'https://staging.example.supabase.co',
    STAGING_SUPABASE_ANON_KEY: 'publishable-key',
    STAGING_ORGANIZER_ACCESS_TOKEN: 'operator-session-token',
  });
  assert.equal(config.supabaseUrl, 'https://staging.example.supabase.co');
  assert.equal(config.guestOrigin, 'https://weddingos-staging.pages.dev');
  assert.throws(() => fixtureConfig({
    STAGING_SUPABASE_URL: 'http://staging.example.supabase.co',
    STAGING_SUPABASE_ANON_KEY: 'publishable-key',
    STAGING_ORGANIZER_ACCESS_TOKEN: 'operator-session-token',
  }), /HTTPS/);
});
